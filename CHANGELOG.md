# Changelog

## v0.2.1

* One subquery was causing unnecessary sequence scan. Replaced with more hacky looking but better performing implementation.

## v0.2.0

* Fixes a crucial bug resulting in highly inefficient query plan resulting in really bad scaling
