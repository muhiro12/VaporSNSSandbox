SWIFT?=swift

.PHONY: dev seed reset

dev:
	$(SWIFT) run Run

seed:
	cp -f Resources/seed.json db.json
	@echo "Seed applied to db.json"

reset:
	echo '{"users":[{"id":"me","displayName":"Trainee","avatarUrl":null}],"posts":[]}' > db.json
	@echo "DB reset"

