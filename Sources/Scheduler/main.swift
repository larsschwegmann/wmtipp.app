import Foundation
import SwiftCron

let repeatInterval: TimeInterval = 60 //s

@discardableResult
func shell(_ args: String...) -> Int32 {
    let task = Process()
    task.launchPath = "/usr/bin/env"
    task.arguments = args
    task.launch()
    task.waitUntilExit()
    return task.terminationStatus
}

let cron = Cron(frequency: 10)

let job = CronJob({
    print("Running Openliga poll command...")
    shell("Run", "pull-openliga")
}, executeAfter: Date(), allowsSimultaneous: false, repeats: true, repeatEvery: repeatInterval)


cron.add(job)
cron.start()
