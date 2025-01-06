//
//  DispatchQueueExecutor.swift
//  Capture
//
//  Created by Quentin Fasquel on 01/01/2025.
//

import Foundation

final class DispatchQueueExecutor: SerialExecutor {
     private let queue: DispatchQueue

     init(queue: DispatchQueue) {
         self.queue = queue
     }

     func enqueue(_ job: UnownedJob) {
         queue.async {
             job.runSynchronously(on: self.asUnownedSerialExecutor())
         }
     }

     func asUnownedSerialExecutor() -> UnownedSerialExecutor {
         UnownedSerialExecutor(ordinary: self)
     }

    func checkIsolated() {
        dispatchPrecondition(condition: .onQueue(queue))
    }
}
