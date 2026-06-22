local Hydrology = {}

function Hydrology.describeReservationHooks()
	return {
		Enabled = false,
		Reason = "Water generation is intentionally out of scope for WorldGen V1",
		ReservedAPIs = {
			"collectCrossingCandidates",
			"reserveBridgeSpans",
			"stampRiverCorridors",
		},
	}
end

return Hydrology
