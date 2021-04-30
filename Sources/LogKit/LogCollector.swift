//===----------------------------------------------------------------------===//
//
// This source file is part of the Soto for AWS open source project
//
// Copyright (c) 2017-2020 the Soto project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Soto project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//


//
//  LogCollector.swift
//  
//
//  Created by Joel Saltzman on 3/24/21.
//
// Slight tweaks to soto's LoggingCollector to prevent name collision and use DispatchQueue
// instead of Lock. I'm trying to keep this package's dependencies to a minimum.

import Foundation
import Logging

/// This is a LogHandler, you should call `Logger.CollectingLogger` to use it.
/// When it's told to log, it will send it to the output as well as collect it in the logs collection.
public struct LogCollector: LogHandler {
    public var metadata: Logger.Metadata = [:]
    public var logLevel: Logger.Level
    public var logs: Logs
    public var internalHandler: LogHandler

    public class Logs {
        public struct Entry {
            public var level: Logger.Level
            public var message: String
            public var metadata: [String: String]
        }

        private var queue = DispatchQueue.init(label: "Log Queue")
        private var logs: [Entry] = []
        
        init() {}

        public var allEntries: [Entry] {
            var result = [Entry]()
            queue.sync {
                result = self.logs
            }
            return result
        }

        public func append(level: Logger.Level, message: Logger.Message, metadata: Logger.Metadata?) {
            queue.sync {
                self.logs.append(Entry(
                    level: level,
                    message: message.description,
                    metadata: metadata?.mapValues { $0.description } ?? [:]
                ))
            }
        }

        public func filter(_ test: (Entry) -> Bool) -> [Entry] {
            return self.allEntries.filter { test($0) }
        }

        public func filter(message: String) -> [Entry] {
            return self.allEntries.filter { $0.message == message }
        }

        public func filter(metadata: String) -> [Entry] {
            return self.allEntries.filter { $0.metadata[metadata] != nil }
        }

        public func filter(metadata: String, with value: String) -> [Entry] {
            return self.allEntries.filter { $0.metadata[metadata] == value }
        }
    }

    init(_ logs: LogCollector.Logs = .init(), logLevel: Logger.Level = .info) {
        self.logLevel = logLevel
        self.logs = logs
        self.internalHandler = StreamLogHandler.standardOutput(label: "_internal_")
        self.internalHandler.logLevel = logLevel
    }

    public func log(level: Logger.Level,
                    message: Logger.Message,
                    metadata: Logger.Metadata? = nil,
                    source: String = "",
                    file: String = #file,
                    function: String = #function,
                    line: UInt = #line) {
        let metadata = self.metadata.merging(metadata ?? [:]) { $1 }
        self.internalHandler.log(level: level,
                                 message: message,
                                 metadata: metadata,
                                 source: source,
                                 file: file,
                                 function: function,
                                 line: line)
        self.logs.append(level: level, message: message, metadata: metadata)
    }

    public subscript(metadataKey key: String) -> Logger.Metadata.Value? {
        get {
            return self.metadata[key]
        }
        set {
            self.metadata[key] = newValue
        }
    }
}
