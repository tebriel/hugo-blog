.PHONY: date release run

NOW=$(shell printf `cat TAG`)

all: date release

run:
	hugo server --theme=hugo-zen --buildDrafts --watch

release:
	./scripts/release.sh ${NOW}

date:
	echo `date +%s` > TAG
