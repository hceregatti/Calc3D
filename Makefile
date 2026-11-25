APP := build/Calc3D.app
CLT := /Library/Developer/CommandLineTools

# Sem o Xcode completo, o swift-testing precisa destes caminhos explícitos.
# Com o Xcode instalado, `swift test` puro também funciona.
TEST_FLAGS := $(if $(wildcard $(CLT)/usr/lib/swift/host/plugins/testing), \
	-Xswiftc -plugin-path -Xswiftc $(CLT)/usr/lib/swift/host/plugins/testing \
	-Xswiftc -F -Xswiftc $(CLT)/Library/Developer/Frameworks \
	-Xlinker -F -Xlinker $(CLT)/Library/Developer/Frameworks \
	-Xlinker -rpath -Xlinker $(CLT)/Library/Developer/Frameworks)

.PHONY: build run test app dmg open install clean web web-test web-build windows windows-test windows-dist

build:          ## Compila em modo debug
	swift build

run:            ## Executa direto (debug)
	swift run Calc3D

test:           ## Roda os testes do núcleo de cálculo
	swift test $(TEST_FLAGS)

app:            ## Gera o .app em release (universal: arm64 + x86_64)
	./scripts/build-app.sh

dmg: app        ## Gera o instalador .dmg em build/
	./scripts/build-dmg.sh

open: app       ## Gera e abre o .app
	open "$(APP)"

install: app    ## Copia o .app para /Applications
	rm -rf "/Applications/Calculadora 3D.app" "/Applications/Calc3D.app"
	cp -R "$(APP)" /Applications/

clean:
	rm -rf .build build web/dist windows/dist windows/release

web:            ## Versão web em modo desenvolvimento
	cd web && npm install && npm run dev

web-test:       ## Testes da versão web
	cd web && npm install && npm test

web-build:      ## Gera a versão web em web/dist
	cd web && npm install && npm run build

windows:        ## App Windows (Electron) em modo desenvolvimento; roda também no macOS
	cd web && npm install
	cd windows && npm install && npm start

windows-test:   ## Testes do app Windows e do que ele reaproveita da web
	cd web && npm install && npm test
	cd windows && npm install && npm test && npm run typecheck

windows-dist:   ## Gera o instalador .exe em windows/release (precisa ser no Windows)
	cd web && npm install
	cd windows && npm install && npm run dist
