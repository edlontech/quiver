# Changelog

## [0.1.3](https://github.com/edlontech/quiver/compare/v0.1.2...v0.1.3) (2026-03-06)


### Bug Fixes

* Using markdown benchee ([a05bcea](https://github.com/edlontech/quiver/commit/a05bceae3d2d300b145899edc829918298e1bad7))

## [0.1.2](https://github.com/edlontech/quiver/compare/v0.1.1...v0.1.2) (2026-03-06)


### Bug Fixes

* Fixed connection leak in HTTP/2 ([a4b8798](https://github.com/edlontech/quiver/commit/a4b8798d0e5a25864c6ae6ffe18ed6e33abaffbe))
* Fixed lower-case header for http/2, according to the RFC ([9d38e2c](https://github.com/edlontech/quiver/commit/9d38e2c7c28f7a2209856e1ea21dcae26938e1aa))
* Improved HTTP/2 performance ([5fc4622](https://github.com/edlontech/quiver/commit/5fc46226d732aaba7c410358eeeddeae40e6c370))
* Running benchmark on CI ([a59acda](https://github.com/edlontech/quiver/commit/a59acda50aa89661322f79a7cd804822751a7709))

## [0.1.1](https://github.com/edlontech/quiver/compare/v0.1.0...v0.1.1) (2026-03-05)


### Bug Fixes

* Fix TLS wildcard SAN matching for OTP 27+ ([ef70ed2](https://github.com/edlontech/quiver/commit/ef70ed20130d3b22aad44b07c59f91724d3dbe99))

## 0.1.0 (2026-03-04)


### Features

* Added Tesla adapter ([443ce43](https://github.com/edlontech/quiver/commit/443ce43edf5826542e012927f6da553daccc955f))
* Config validation and supervision tree ([6d0e0d6](https://github.com/edlontech/quiver/commit/6d0e0d689ada955861b2055cf33a5656acf15eb3))
* Default supervisor name so clients don't need to pass it ([cc882f5](https://github.com/edlontech/quiver/commit/cc882f5c6ff048efbcb2760f2cc12421a795bd16))
* HTTP/1 connection pool with NimblePool ([a587bff](https://github.com/edlontech/quiver/commit/a587bff25dc5029ef2d3df69e02561f4ec668d71))
* HTTP/1 connection with keep-alive ([b939476](https://github.com/edlontech/quiver/commit/b939476fe65aad458d234f7ea9c94eae65c94e40))
* HTTP/2 connection with HPACK and ALPN ([f60b9ae](https://github.com/edlontech/quiver/commit/f60b9ae8c8236fb75a96f510c02fa110ba98ed85))
* HTTP/2 pool with coordinator and connection worker ([8106d92](https://github.com/edlontech/quiver/commit/8106d92b9677fb59a6ea2fa3a00e4318d8965e8b))
* Pool manager with dynamic routing ([243c1a9](https://github.com/edlontech/quiver/commit/243c1a9f034766aaa79a4bf720e9d27b54276704))
* Project setup with error system and data structures ([2da80ac](https://github.com/edlontech/quiver/commit/2da80acbc084e1e0e1243134cdeb5065aa29b3f7))
* Public request API ([bfaec03](https://github.com/edlontech/quiver/commit/bfaec03e72b814c9b5a5fae3934d25023999c24c))
* Streaming response support ([d18db59](https://github.com/edlontech/quiver/commit/d18db5914b657eff0af4427b3116620cfc4cfd42))
* Telemetry instrumentation ([9c0df30](https://github.com/edlontech/quiver/commit/9c0df30ee8a22ad45805ad4b19d9db32feb0e1d4))
* Transport layer with TCP and SSL ([c0dbccc](https://github.com/edlontech/quiver/commit/c0dbccc5fa608d26b8396b5eb6d8865ed373bcf7))


### Bug Fixes

* Fixed ALPN pool detectin ([dbc96de](https://github.com/edlontech/quiver/commit/dbc96de41717fd1985834299215c474807cd6bad))

## Changelog
