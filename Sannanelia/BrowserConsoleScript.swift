//
//  BrowserConsoleScript.swift
//  Sannanelia
//
//  Created by Tufan Cakir on 07.11.26.
//

import WebKit

enum BrowserConsoleScript {
    static let source = #"""
        (() => {
            if (window.__sannaneliaConsoleInstalled) return;

            Object.defineProperty(
                window,
                "__sannaneliaConsoleInstalled",
                { value: true }
            );

            const bridge = window.webkit?.messageHandlers
                ?.sannaneliaConsole;

            if (!bridge) return;

            function stringify(value) {
                try {
                    if (typeof value === "string") return value;
                    if (value instanceof Error) {
                        return value.stack || value.message;
                    }
                    if (value === undefined) return "undefined";
                    if (typeof value === "bigint") {
                        return value.toString() + "n";
                    }

                    const json = JSON.stringify(value);
                    return json === undefined
                        ? String(value)
                        : json;
                } catch (_) {
                    return String(value);
                }
            }

            function send(level, values) {
                try {
                    bridge.postMessage({
                        level,
                        text: values.map(stringify).join(" ")
                            .slice(0, 10000)
                    });
                } catch (_) {}
            }

            for (const level of [
                "log", "info", "warn", "error", "debug"
            ]) {
                const original = console[level];

                console[level] = function(...args) {
                    send(level, args);

                    return original.apply(console, args);
                };
            }

            window.addEventListener("error", event => {
                send("error", [
                    event.message,
                    event.filename + ":" + event.lineno
                ]);
            });

            window.addEventListener(
                "unhandledrejection",
                event => {
                    send("error", [
                        "Unhandled Promise Rejection:",
                        event.reason
                    ]);
                }
            );
        })();
        """#
}
