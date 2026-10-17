class_name Offer
extends RefCounted
## A contract offer shown in the Clubs app. Accepting it turns it into a Contract.

var club_id: String = ""
var wage: int = 0
var years: int = 0
var release_clause: int = 0
var role: String = CareerRules.BENCH
var is_youth: bool = false
var is_renewal: bool = false


func to_contract() -> Contract:
	var contract := Contract.new()
	contract.club_id = club_id
	contract.wage = wage
	contract.years_left = years
	contract.release_clause = release_clause
	contract.is_youth = is_youth
	return contract
