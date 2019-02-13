# Perfect-NIOCompat
Perfect 3 -> 4 compatability 

In Package.swift:

`.package(url: "https://github.com/PerfectlySoft/Perfect-NIOCompat.git", .branch("master"))`

<strike>`.package(url: "https://github.com/PerfectlySoft/Perfect-HTTP.git", ...`</strike>
<strike>`.package(url: "https://github.com/PerfectlySoft/Perfect-HTTPServer.git", ...`</strike>
<strike>`.package(url: "https://github.com/PerfectlySoft/Perfect-Mustache.git", ...`</strike>
<strike>`.package(url: "https://github.com/PerfectlySoft/Perfect-WebSockets.git", ...`</strike>

Use PerfectCURL, PerfectSMTP, PerfectNotifications `from: "4.0.0"`

In source files:

`import PerfectNIOCompat`

<strike>import PerfectHTTP</strike>

<strike>import PerfectHTTPServer</strike>

<strike>import PerfectMustache</strike>

<strike>import PerfectWebSockets</strike>

No access to raw connection

<strike>HTTPRequest.connection: NetTCP</strike>

No mutable HTTPRequest

<strike>HTTPRequest.addHeader(...)</strike>

<strike>HTTPRequest.setHeader(...)</strike>

No multiplexer or HTTP/2

<strike>HTTPMultiplexer</strike>

<strike>HTTP/2, ALPN</strike>

