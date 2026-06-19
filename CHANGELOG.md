Changelog
=========

Unreleased
----------
* fix: add configurable per-operation HTTP timeouts (connect/write/read) to every request and to authentication, so an unresponsive Efí endpoint raises `HTTP::TimeoutError` instead of hanging the process indefinitely. Configurable via the `timeout` option or the `EFI_HTTP_CONNECT_TIMEOUT` / `EFI_HTTP_WRITE_TIMEOUT` / `EFI_HTTP_READ_TIMEOUT` env vars (defaults: 10/10/30s).
* fix: validate the certificate (PEM) when first used and fail fast with a clear `SdkRubyApisEfi::CertificateError` for missing, encrypted, or cert-only files — no more passphrase prompts hanging on a TTY-less worker. The PEM is now read and parsed once per instance instead of twice on every request.
* docs: document the expected PEM format (certificate + non-encrypted RSA key) and the timeout configuration.

Version 1.0.2 (2023-11-06)
--------------------------
* feat: ofCancelSchedulePix added into Open Finance

Version 1.0.1 (2023-09-20)
--------------------------
* docs: Updated examples
    - All methods now are in cammelCase instead of snake_case
    - New method pixSendDetailId
    - Method getAccountCertificate renamed to createAccountCertificate and HTTP Method updated to POST instead of GET

* chore: Changed header 'api-sdk'

Version 1.0.0 (2023-07-31)
--------------------------
* Initial release
