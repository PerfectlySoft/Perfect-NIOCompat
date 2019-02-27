# Perfect-NIOCompat
Perfect 3 -> 4 compatability 

This package provides compatability for Perfect 3 apps to run on Perfect 4 NIO with minimal changes.

In Package.swift:

Add:

`.package(url: "https://github.com/PerfectlySoft/Perfect-NIOCompat.git", .branch("master"))`

Remove:

<strike>`.package(url: "https://github.com/PerfectlySoft/Perfect-HTTP.git", ...`</strike>

<strike>`.package(url: "https://github.com/PerfectlySoft/Perfect-HTTPServer.git", ...`</strike>

<strike>`.package(url: "https://github.com/PerfectlySoft/Perfect-Mustache.git", ...`</strike>

<strike>`.package(url: "https://github.com/PerfectlySoft/Perfect-WebSockets.git", ...`</strike>

Compatability for the four packages above are included herein.

<hr>

If you are using PerfectCURL, PerfectSMTP, or PerfectNotifications, make sure the version is `from: "4.0.0"`.

<hr>

In source files:

Add:

`import PerfectNIOCompat`

Remove:

<strike>import PerfectHTTP</strike>

<strike>import PerfectHTTPServer</strike>

<strike>import PerfectMustache</strike>

<strike>import PerfectWebSockets</strike>

<hr>

The following is no longer supported:

No access to raw connection

<strike>HTTPRequest.connection: NetTCP</strike>

No mutable HTTPRequest

<strike>HTTPRequest.addHeader(...)</strike>

<strike>HTTPRequest.setHeader(...)</strike>

No multiplexer or HTTP/2

<strike>HTTPMultiplexer</strike>

<strike>HTTP/2, ALPN</strike>

