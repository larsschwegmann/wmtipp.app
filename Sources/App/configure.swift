import FluentPostgreSQL
import Redis
import Vapor
import Authentication
import Leaf

/// Called before your application initializes.
public func configure(_ config: inout Config, _ env: inout Environment, _ services: inout Services) throws {
    /// Register providers first
    //try services.register(FluentSQLiteProvider())
    try services.register(FluentPostgreSQLProvider())
    try services.register(LeafProvider())
    try services.register(AuthenticationProvider())

    /// Register routes to the router
    let router = EngineRouter.default()
    try routes(router)
    services.register(router, as: Router.self)

    /// Register middleware
    var middlewares = MiddlewareConfig() // Create _empty_ middleware config
    middlewares.use(FileMiddleware.self) // Serves files from `Public/` directory
    middlewares.use(ErrorMiddleware.self) // Catches errors and converts to HTTP response
    middlewares.use(SessionsMiddleware.self)
    services.register(middlewares)
    
    //Configure Psotgres
    //let postgres = PostgreSQLDatabase(config: PostgreSQLDatabaseConfig(hostname: "127.0.0.1", port: 5432, username: "lars", database: "wm2018", password: nil, transport: .cleartext))
    //var databases = DatabasesConfig()
    
    var databases = DatabasesConfig()
    let databaseConfig: PostgreSQLDatabaseConfig
    if let url = Environment.get("DATABASE_URL_RDS") {
        databaseConfig = try PostgreSQLDatabaseConfig(url: url)
    } else {
        let databaseName: String
        let databasePort: Int
        if (env == .testing) {
            databaseName = "wm2018"
            if let testPort = Environment.get("DATABASE_PORT") {
                databasePort = Int(testPort) ?? 5432
            } else {
                databasePort = 5432
            }
        } else {
            databaseName = Environment.get("DATABASE_DB") ?? "wm2018"
            databasePort = 5432
        }
        
        let hostname = Environment.get("DATABASE_HOSTNAME") ?? "localhost"
        let username = Environment.get("DATABASE_USER") ?? "lars"
        let password = Environment.get("DATABASE_PASSWORD") ?? nil
        databaseConfig = PostgreSQLDatabaseConfig(hostname: hostname, port: databasePort, username: username, database: databaseName, password: password)
    }
    
    let postgres = PostgreSQLDatabase(config: databaseConfig)
    
    //Redis config
    let redisConfig: RedisClientConfig
    if let redisURL = Environment.get("REDIS_URL") {
        redisConfig = RedisClientConfig(url: URL(string: redisURL)!)
    } else {
        redisConfig = RedisClientConfig()
    }
    
    let redis = try RedisDatabase(config: redisConfig)
    
    databases.add(database: postgres, as: .psql)
    databases.add(database: redis, as: .redis)
    databases.enableLogging(on: .psql)
    services.register(databases)
    
    // Create a new, empty pool config with max 20 connection (heroku limit)
    let poolConfig = DatabaseConnectionPoolConfig(maxConnections: 10)
    
    // Register the pool config.
    services.register(poolConfig)

    /// Configure migrations
    var migrations = MigrationConfig()
    migrations.add(model: Team.self, database: .psql)
    migrations.add(model: Group.self, database: .psql)
    migrations.add(model: Goal.self, database: .psql)
    migrations.add(model: Location.self, database: .psql)
    migrations.add(model: MatchResult.self, database: .psql)
    migrations.add(model: Match.self, database: .psql)
    migrations.add(model: Community.self, database: .psql)
    migrations.add(model: User.self, database: .psql)
    migrations.add(model: CommunityUserPivot.self, database: .psql)
    migrations.add(model: Bet.self, database: .psql)
    migrations.add(model: News.self, database: .psql)
    migrations.add(model: Scoreboard.self, database: .psql)
    
    //Migration for PROD sys on heroku because I forgot to add the date. stupid me.
    if env == Environment.production {
        migrations.add(name: "add_news_date", database: .psql) { (conn, revert) -> EventLoopFuture<Void> in
            return PostgreSQLDatabase.update(News.self, on: conn, closure: { updater in
                if revert {
                    try updater.removeField(for: \.date)
                } else {
                    try updater.field(for: \.date)
                }
            }).transform(to: ())
        }
    }
    
    services.register(migrations)
    
    // Configure the rest of your application here
    var commandConfig = CommandConfig.default()
    commandConfig.use(RevertCommand.self, as: "revert")
    commandConfig.use(SetupCommand(), as: "setup")
    commandConfig.use(OpenLigaPullCommand(), as: "pull-openliga")
    commandConfig.use(ScoreboardTrackerCommand(), as: "track-scores")
    services.register(commandConfig)
    
    //Mailgun
    
    if let mailgunAPIKey = Environment.get("MAILGUN_API_KEY") {
        MailgunService.apiKey = mailgunAPIKey
    } else {
        //TODO: HAndle this somehow
    }
    
    services.register { container -> LeafConfig in
        // take a copy of Leaf's default tags
        var tags = LeafTagConfig.default()
        tags.use(ArrayGet(), as: "arrayGet")
        tags.use(IntConvert(), as: "int")
        tags.use(DateIsBefore(), as: "dateIsBefore")
        tags.use(RelativeDateFormat(), as: "relativeDate")
        
        // find the location of our Resources/Views directory
        let directoryConfig = try container.make(DirectoryConfig.self)
        let viewsDirectory = directoryConfig.workDir + "Resources/Views"
        
        // put all that into a new Leaf configuration and return it
        return LeafConfig(tags: tags, viewsDir: viewsDirectory, shouldCache: false)
    }
    
    services.register(KeyedCache.self) { container -> DatabaseKeyedCache<ConfiguredDatabase<RedisDatabase>> in
        return try container.keyedCache(for: .redis)
    }
    
    config.prefer(LeafRenderer.self, for: ViewRenderer.self)
    config.prefer(DatabaseKeyedCache<ConfiguredDatabase<RedisDatabase>>.self, for: KeyedCache.self)
}
