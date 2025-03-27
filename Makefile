ARTIFACTS_DIR = ./artifacts

.PHONY: so
so:
	@echo "Building .so for Linux..."
	docker build -f build/Dockerfile . --target=copy-so -o type=local,dest=$(ARTIFACTS_DIR)

# Сборка .dll (Windows через Docker + Mingw)
.PHONY: dll
dll:
	@echo "Building .dll for Windows using Docker..."
	docker build -f build/Dockerfile . --target=copy-dll -o type=local,dest=$(ARTIFACTS_DIR)

# Очистка
.PHONY: clean
clean:
	rm -f $(ARTIFACTS_DIR/*.so $(ARTIFACTS_DIR/*.dll
