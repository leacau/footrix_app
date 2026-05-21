import { defineSecret, defineString } from 'firebase-functions/params';

export const THESPORTSDB_BASE_URL = defineString('THESPORTSDB_BASE_URL');
export const FOOTBALL_DATA_TOKEN = defineSecret('FOOTBALL_DATA_TOKEN');

export const FOOTBALL_DATA_BASE_URL = 'https://api.football-data.org/v4';

export const FOOTBALL_DATA_COMPETITIONS: Record<
	string,
	{ name: string; country: string; source: 'football-data' }
> = {
	WC: { name: 'FIFA World Cup', country: 'World', source: 'football-data' },
	CL: {
		name: 'UEFA Champions League',
		country: 'Europe',
		source: 'football-data',
	},
	BL1: { name: 'Bundesliga', country: 'Germany', source: 'football-data' },
	DED: { name: 'Eredivisie', country: 'Netherlands', source: 'football-data' },
	BSA: {
		name: 'Campeonato Brasileiro Serie A',
		country: 'Brazil',
		source: 'football-data',
	},
	PD: { name: 'Primera Division', country: 'Spain', source: 'football-data' },
	FL1: { name: 'Ligue 1', country: 'France', source: 'football-data' },
	ELC: { name: 'Championship', country: 'England', source: 'football-data' },
	PPL: { name: 'Primeira Liga', country: 'Portugal', source: 'football-data' },
	EC: {
		name: 'European Championship',
		country: 'Europe',
		source: 'football-data',
	},
	SA: { name: 'Serie A', country: 'Italy', source: 'football-data' },
	PL: { name: 'Premier League', country: 'England', source: 'football-data' },
};

export const ARGENTINA_LEAGUE = {
	id: 'ARG',
	name: 'Argentinian Primera Division',
	shortName: 'Argentina',
	country: 'Argentina',
	apiSource: 'thesportsdb',
	apiLeagueId: '4406',
};
