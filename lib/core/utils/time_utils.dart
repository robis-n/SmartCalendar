/// Canonical timestamp convention for the whole app.
///
/// Postgres columns are `timestamptz`. A zone-less ISO string (what
/// `DateTime.toIso8601String()` produces for local times) gets interpreted
/// by Postgres as UTC — which silently shifts every schedule by the device's
/// UTC offset. That bug made notifications fire hours late.
///
/// Rule: **send UTC, show local.**
///  - Everything written to the DB goes through [tsToDb].
///  - Everything read from the DB goes through [tsFromDb] / [tsTryFromDb].
library;

String tsToDb(DateTime t) => t.toUtc().toIso8601String();

DateTime tsFromDb(String s) => DateTime.parse(s).toLocal();

DateTime? tsTryFromDb(String? s) =>
    s == null ? null : DateTime.tryParse(s)?.toLocal();
