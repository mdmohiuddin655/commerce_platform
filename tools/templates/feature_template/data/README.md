Repository implementations, DTO mapping and adapters. Converts wire/DTO shapes
into `domain` types and never leaks a Firestore/HTTP type outward. Cached data
is display-only: inventory is checked and reserved by the backend.
