import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

// Sync fixtures cada 6 horas para ligas activas
export const scheduledFixtureSync = functions.pubsub
  .schedule('every 6 hours')
  .onRun(async () => {
    const db = admin.firestore();
    
    // Obtener ligas activas
    const leaguesSnap = await db.collection('leagues')
      .where('active', isEqualTo: true)
      .get();
    
    let totalSynced = 0;
    
    for (const leagueDoc of leaguesSnap.docs) {
      const league = leagueDoc.data();
      const apiLeagueId = league.apiFootballId;
      const season = league.currentSeason;
      
      if (!apiLeagueId || !season) continue;
      
      try {
        // Llamar a la función de sync (simulando onCall)
        const result = await syncFixturesForLeague(apiLeagueId, season);
        totalSynced += result.synced;
        console.log(`✅ Synced ${result.synced} fixtures for league ${league.name}`);
      } catch (error) {
        console.error(`❌ Error syncing league ${league.name}:`, error);
      }
    }
    
    console.log(`🎉 Scheduled sync complete: ${totalSynced} fixtures synced`);
    return null;
  });

// Función auxiliar reutilizable
async function syncFixturesForLeague(apiLeagueId: number, season: number) {
  // ... misma lógica que syncFixtures, pero sin el wrapper onCall
  // (código refactorizado para ser llamado desde scheduledSync y desde onCall)
  return { synced: 0 }; // Placeholder
}