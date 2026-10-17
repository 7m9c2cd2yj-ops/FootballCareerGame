class_name CareerSaves
extends RefCounted
## Career-specific glue for SaveSlots: builds envelopes with a slot summary,
## and migrates + validates careers when loading.


static func summary_for(career: CareerState, balance: Balance, world: ClubWorld) -> Dictionary:
	return {
		"display_name": career.player.display_name,
		"position": career.player.position,
		"age": career.player.age,
		"overall": career.player.overall_rating(balance),
		"seasons": career.history.size(),
		"club":
		world.club(career.club_id).name if world.has_club(career.club_id) else career.club_id,
		"retired": career.retired,
	}


static func envelope_for(
	career: CareerState, balance: Balance, world: ClubWorld, previous_revision: int, now_unix: int
) -> SaveEnvelope:
	return SaveEnvelope.create(
		career.to_dict(), summary_for(career, balance, world), previous_revision, now_unix
	)


static func migrator(rules: CareerRules) -> Callable:
	return func(data: Dictionary) -> Dictionary:
		return CareerMigration.migrate(data, rules.academy_club)


static func validator(balance: Balance, world: ClubWorld) -> Callable:
	return func(data: Dictionary) -> Array[String]:
		return CareerState.validate_dict(data, balance, world)
