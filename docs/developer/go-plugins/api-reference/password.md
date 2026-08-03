---
title: password Package
description: Complete password comparison, salted SHA, preparation, and full-hash helper reference
keywords: [pluginapi password, CompareHash, CryptPassword, GenerateHash, FullHash]
sidebar_position: 12
---

# `password` Package

```go
import "github.com/croessner/nauthilus/v3/pluginapi/v1/password"
```

This package works with credentials. Avoid the string/byte convenience functions when a request-scoped `pluginapi.Secret` is available; they make secret lifetime and copying harder to control.

## Public errors

```go
var ErrUnsupportedAlgorithm = errors.New("unsupported hash algorithm")
var ErrUnsupportedEncoding = errors.New("unsupported password encoding")
```

`ErrUnsupportedAlgorithm` covers salted-SHA algorithms/prefixes outside the public contract and malformed salted-SHA inputs that cannot supply a valid salt. `ErrUnsupportedEncoding` covers non-base64/non-hex salted-SHA encoding choices. Decode and external `crypt` errors can also be returned; use `errors.Is` only for the two sentinels.

## `Algorithm`

```go
type Algorithm uint8
```

| Constant | Numeric value | Meaning |
| --- | ---: | --- |
| `AlgorithmUnknown` | 0 | Unsupported/unparsed algorithm. |
| `AlgorithmSSHA256` | 1 | Salted SHA-256. |
| `AlgorithmSSHA512` | 2 | Salted SHA-512. |

Only SSHA-256 and SSHA-512 are accepted by `CryptPassword.Generate...`.

## `Encoding`

```go
type Encoding uint8
```

| Constant | Numeric value | Meaning |
| --- | ---: | --- |
| `EncodingUnknown` | 0 | Unsupported/unparsed encoding. |
| `EncodingBase64` | 1 | Standard base64 of digest concatenated with salt. |
| `EncodingHex` | 2 | Lowercase hexadecimal of digest concatenated with salt. |

## `CryptPassword`

```go
type CryptPassword struct {
    Salt      []byte
    Password  string
    Algorithm Algorithm
    Encoding  Encoding
}
```

| Field | Meaning |
| --- | --- |
| `Salt` | Copied salt bytes parsed or used for generation. Secret-sensitive. |
| `Password` | Encoded `digest || salt` payload **without** the SSHA-family prefix shown below. |
| `Algorithm` | Parsed/generated algorithm. |
| `Encoding` | Parsed/generated payload encoding. |

The object is mutable and not documented as concurrency-safe. Zero values represent no parsed/generated password.

### `(*CryptPassword).GenerateString`

```go
func (c *CryptPassword) GenerateString(
    plainPassword string,
    salt []byte,
    algorithm Algorithm,
    encoding Encoding,
) (string, error)
```

Converts the plaintext string to bytes and delegates to `GenerateBytes`. Prefer the byte or `Secret` paths to avoid immutable plaintext strings.

### `(*CryptPassword).GenerateBytes`

```go
func (c *CryptPassword) GenerateBytes(
    plainPassword []byte,
    salt []byte,
    algorithm Algorithm,
    encoding Encoding,
) (string, error)
```

Computes `SHA-256(password || salt)` or `SHA-512(password || salt)`, appends the salt to the digest, encodes the combined bytes, copies the salt into the receiver, and sets all fields. It returns only the encoded payload. To store a full hash, the caller must add one of the matching SSHA-family prefixes shown below: `SSHA256` uses default base64 and `SSHA512.HEX` selects SHA-512 plus hex. Unknown algorithms/encodings return the public sentinels. Empty salt is accepted for generation, but such output cannot later pass `GetParameters` because the parser requires payload bytes beyond the fixed digest length.

### `(*CryptPassword).GetParameters`

```go
func (c *CryptPassword) GetParameters(
    cryptedPassword string,
) (salt []byte, algorithm Algorithm, encoding Encoding, err error)
```

Accepts the exact case-sensitive form:

```text
{SSHA256}<payload>
{SSHA256.B64}<payload>
{SSHA256.HEX}<payload>
{SSHA512}<payload>
{SSHA512.B64}<payload>
{SSHA512.HEX}<payload>
```

An omitted suffix defaults to base64. It decodes the payload, requires at least one salt byte after the 32- or 64-byte digest, stores the payload/metadata and a copied salt, and returns a separate salt copy. Prefix/shape/short-payload failures use `ErrUnsupportedAlgorithm`; payload decode errors are returned directly.

## Password comparison

### `CompareHash`

```go
func CompareHash(hashPassword string, plainPassword pluginapi.Secret) (bool, error)
```

Returns `false, nil` for a nil secret. Otherwise it borrows bytes through `Secret.WithBytes` and delegates to `CompareHashBytes`. A callback/secret error is returned. The final encoded comparison is constant-time.

### `CompareHashString`

```go
func CompareHashString(hashPassword, plainPassword string) (bool, error)
```

Converts plaintext to bytes and delegates. It is a convenience API; the plaintext string cannot be cleared.

### `CompareHashBytes`

```go
func CompareHashBytes(hashPassword string, plainPassword []byte) (bool, error)
```

Hashes whose prefix begins with an opening brace followed by `SSHA` use the salted-SHA parser/generator above. Other hashes are decoded and verified through the package's `github.com/simia-tech/crypt` dependency using the settings embedded in the stored hash. Unsupported/malformed formats or dependency errors are returned. It compares the full recomputed encoded hash with the stored hash using `subtle.ConstantTimeCompare`.

The function does not clear caller-owned plaintext bytes. The caller owns their lifetime.

## `HashOptions`

```go
type HashOptions struct {
    Nonce   []byte
    DevMode bool
}
```

`Nonce` is prepended before a NUL separator. It is not copied by the struct. `DevMode` is retained for source compatibility and no longer changes the generated hash.

## Full-hash functions

### `GenerateHash`

```go
func GenerateHash(secret pluginapi.Secret, options HashOptions) (string, error)
```

Returns `"", nil` for a nil secret. Otherwise it borrows secret bytes, calls `GenerateHashBytes`, and returns any `Secret.WithBytes` error.

### `GenerateHashString`

```go
func GenerateHashString(password string, options HashOptions) string
```

String convenience wrapper around `GenerateHashBytes`.

### `GenerateHashBytes`

```go
func GenerateHashBytes(password []byte, options HashOptions) string
```

Builds the prepared byte sequence, defers `clear` on that temporary slice, and calls `FullHash`. It cannot clear caller-owned password/nonce inputs or the returned string.

### `PrepareBytes`

```go
func PrepareBytes(password, nonce []byte) []byte
```

Allocates and returns:

```text
nonce || 0x00 || password
```

The separator is present even for an empty nonce. Caller owns and should clear the returned slice after use.

### `FullHash`

```go
func FullHash(value []byte) string
```

Returns the canonical lowercase 64-character SHA-256 digest of `value`. `GenerateHash`, `GenerateHashString`, and `GenerateHashBytes` use this full digest in every runtime mode. The host supplies the same form through `PostActionRequest.PasswordHash`; integrations that need a bounded correlation field must validate the digest before deriving their own shortened representation.
