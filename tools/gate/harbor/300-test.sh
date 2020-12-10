#!/bin/bash

set -eux

helm test harbor -n harbor
