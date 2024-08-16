run:
    odin run src --out:bin/scatter

build:
    odin build src --out:bin/scatter

test:
    odin test src

release:
    odin build src --out:bin/scatter -o:aggressive
