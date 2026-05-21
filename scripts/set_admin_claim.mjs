import { applicationDefault, initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';

const email = process.argv[2];
const enabled = process.argv[3] !== 'false';

if (!email) {
	console.error('Uso: node scripts/set_admin_claim.mjs usuario@email.com [true|false]');
	process.exit(1);
}

initializeApp({
	credential: applicationDefault(),
	projectId: 'footrix-dc5a7',
});

try {
	const auth = getAuth();
	const user = await auth.getUserByEmail(email);
	await auth.setCustomUserClaims(user.uid, { admin: enabled });
	console.log(
		`Claim admin=${enabled} aplicado a ${email}. El usuario debe cerrar y volver a iniciar sesion.`,
	);
} catch (error) {
	console.error('No se pudo actualizar el claim admin:', error);
	process.exit(1);
}
