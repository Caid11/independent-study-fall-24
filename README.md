# Overview

This repository contains the code and data for Kincaid Savoie's Fall 2024 independent study. The goal of the study is to
implement HAMT and CHAMP maps in Koka and optimize them with its functional-in-place and context constructor features.

## How to run tests

- Install Koka
- Run `koka -e test.kk`

## Latest benchmarks

### Array backed insertion

Input size | Time (ms)
10         | 0
100        | 0
1000       | 74
10000      | 6897
100000     | 709298

### HAMT backed insertion

Input size | Time (ms)
10         | 0
100        | 0
1000       | 1
10000      | 18
100000     | 259
