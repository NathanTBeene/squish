# Squish Makefile
# Builds various squish variants

.PHONY: all base minify uglify minify-uglify debug full clean install

all: base

# Base squish (compile, gzip, virtual-io)
base: squish.lua squishy
	lua squish.lua
	chmod +x squish

# Squish with minify support
minify: squish.lua squishy
	@echo "Building squish with minify..."
	@cp squishy squishy.backup
	@cat squishy > squishy.tmp
	@echo 'Module "squish.minify" "minify/squish.minify.lua"' >> squishy.tmp
	@echo 'Module "optlex" "minify/optlex.lua"' >> squishy.tmp
	@echo 'Module "optparser" "minify/optparser.lua"' >> squishy.tmp
	@echo 'Module "llex" "minify/llex.lua"' >> squishy.tmp
	@echo 'Module "lparser" "minify/lparser.lua"' >> squishy.tmp
	@mv squishy.tmp squishy
	lua squish.lua
	@mv squishy.backup squishy
	@rm -f squishy.tmp
	chmod +x squish

# Squish with uglify support
uglify: squish.lua squishy
	@echo "Building squish with uglify..."
	@cp squishy squishy.backup
	@cat squishy > squishy.tmp
	@echo 'Module "squish.uglify" "uglify/squish.uglify.lua"' >> squishy.tmp
	@echo 'Module "uglify.llex" "uglify/llex.lua"' >> squishy.tmp
	@mv squishy.tmp squishy
	lua squish.lua
	@mv squishy.backup squishy
	@rm -f squishy.tmp
	chmod +x squish

# Squish with both minify and uglify
minify-uglify: squish.lua squishy
	@echo "Building squish with minify and uglify..."
	@cp squishy squishy.backup
	@cat squishy > squishy.tmp
	@echo 'Module "squish.minify" "minify/squish.minify.lua"' >> squishy.tmp
	@echo 'Module "optlex" "minify/optlex.lua"' >> squishy.tmp
	@echo 'Module "optparser" "minify/optparser.lua"' >> squishy.tmp
	@echo 'Module "llex" "minify/llex.lua"' >> squishy.tmp
	@echo 'Module "lparser" "minify/lparser.lua"' >> squishy.tmp
	@echo 'Module "squish.uglify" "uglify/squish.uglify.lua"' >> squishy.tmp
	@echo 'Module "uglify.llex" "uglify/llex.lua"' >> squishy.tmp
	@mv squishy.tmp squishy
	lua squish.lua
	@mv squishy.backup squishy
	@rm -f squishy.tmp
	chmod +x squish

# Squish with debug support
debug: squish.lua squishy
	@echo "Building squish with debug..."
	@cp squishy squishy.backup
	@cat squishy > squishy.tmp
	@echo 'Module "squish.debug" "debug/squish.debug.lua"' >> squishy.tmp
	@echo 'Module "debug.minichunkspy" "debug/minichunkspy.lua"' >> squishy.tmp
	@mv squishy.tmp squishy
	lua squish.lua
	@mv squishy.backup squishy
	@rm -f squishy.tmp
	chmod +x squish

# Full-featured squish (all modules)
full: squish.lua squishy
	@echo "Building full-featured squish..."
	@cp squishy squishy.backup
	@cat squishy > squishy.tmp
	@echo 'Module "squish.minify" "minify/squish.minify.lua"' >> squishy.tmp
	@echo 'Module "optlex" "minify/optlex.lua"' >> squishy.tmp
	@echo 'Module "optparser" "minify/optparser.lua"' >> squishy.tmp
	@echo 'Module "llex" "minify/llex.lua"' >> squishy.tmp
	@echo 'Module "lparser" "minify/lparser.lua"' >> squishy.tmp
	@echo 'Module "squish.uglify" "uglify/squish.uglify.lua"' >> squishy.tmp
	@echo 'Module "uglify.llex" "uglify/llex.lua"' >> squishy.tmp
	@echo 'Module "squish.debug" "debug/squish.debug.lua"' >> squishy.tmp
	@echo 'Module "debug.minichunkspy" "debug/minichunkspy.lua"' >> squishy.tmp
	@echo 'Module "squish.gzip" "gzip/squish.gzip.lua"' >> squishy.tmp
	@echo 'Module "gzip.deflatelua" "gzip/deflatelua.lua"' >> squishy.tmp
	@mv squishy.tmp squishy
	lua squish.lua
	@mv squishy.backup squishy
	@rm -f squishy.tmp
	chmod +x squish

# Install to system
install: squish
	install -m 755 squish /usr/local/bin/squish

# Clean build artifacts
clean:
	rm -f squish squish.debug gunzip.lua squishy.tmp squishy.backup
