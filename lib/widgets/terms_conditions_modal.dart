import 'package:flutter/material.dart';

class TermsConditionsModal extends StatelessWidget {
  const TermsConditionsModal({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: true,
      isDismissible: true,
      useRootNavigator: true,
      builder: (context) => const TermsConditionsModal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag indicator
          Container(
            margin: const EdgeInsets.only(top: 8, bottom: 4),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header with close button
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF1F9BD1), Color(0xFF1887B8)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.description_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Conditions Générales d\'Utilisation (CGU)',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF102132),
                        ),
                      ),
                      Text(
                        'Application MyChallenge',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Color(0xFF102132),
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSection(
                    '1. Objet',
                    'Les présentes Conditions Générales d\'Utilisation (ci-après les « CGU ») ont pour objet de définir les modalités d\'accès et d\'utilisation de l\'application d\'incentive MyChallenge (ci-après l\'« Application »), mise à disposition par Novopharma ou sa filiale Medsource (ci-après « l\'Entreprise »), au profit des préparateurs et préparatrices en pharmacie participant au programme de motivation commerciale.\n\nL\'Application MyChallenge permet aux utilisateurs de suivre leurs performances, cumuler des points, consulter leurs récompenses et accéder à diverses informations commerciales dans le cadre des campagnes d\'incentive organisées par l\'Entreprise.\n\nElle leur offre également la possibilité de bénéficier de formations régulières pour améliorer leurs connaissances et de renforcer leur expertise pour mieux conseiller nos marques.',
                  ),

                  _buildSection(
                    '2. Acceptation des CGU',
                    'L\'accès et l\'utilisation de MyChallenge impliquent l\'acceptation pleine et entière des présentes CGU.\n\nTout utilisateur qui n\'accepte pas ces conditions doit s\'abstenir d\'utiliser l\'Application.',
                  ),

                  _buildSection(
                    '3. Accès à l\'Application',
                    'L\'accès à MyChallenge est réservé aux personnes autorisées par Novopharma ou Medsource, dans le cadre d\'un partenariat ou d\'une activité professionnelle avec une pharmacie participante.\n\nL\'inscription et l\'utilisation de l\'Application par un préparateur ou une préparatrice sont soumises à l\'accord préalable du pharmacien titulaire ou du pharmacien responsable de la pharmacie concernée, formalisé par une signature.\n\nL\'accès peut être retiré à tout moment :\n- en cas de non-respect des présentes CGU ou des règles du programme,\n- ou à la demande du pharmacien titulaire ou responsable de la pharmacie participante.',
                  ),

                  _buildSection(
                    '4. Création et gestion du compte utilisateur',
                    '- Chaque utilisateur dispose d\'un compte personnel protégé par un identifiant et un mot de passe.\n- L\'utilisateur s\'engage à ne pas partager ses identifiants et à préserver la confidentialité de ses accès.\n- En cas d\'utilisation frauduleuse ou suspecte, Novopharma / Medsource se réservent le droit de suspendre ou de supprimer le compte concerné.',
                  ),

                  _buildSection(
                    '5. Fonctionnement du programme d\'incentive',
                    '- Les points sont attribués selon les ventes réalisées, objectifs atteints, ou actions spécifiques définies par Novopharma / Medsource, telles que les quiz autour de nos capsules formatives visant à maîtriser et améliorer le conseil de nos produits.\n- Les modalités de calcul, plafonds et barèmes sont communiqués dans l\'Application ou par voie interne.\n- Les points ou récompenses n\'ont pas de valeur monétaire directe et ne peuvent être échangés contre de l\'argent, sauf lorsqu\'ils sont convertis en crédit sur une carte Pluxee, attribuée à titre personnel à l\'utilisateur, après vérification automatique effectuée sur la base des ventes cumulées de l\'équipe officinale, lesquelles ne doivent pas excéder les quantités achetées auprès de Novopharma / Medsource.\n- En cas de cessation du partenariat ou de non-respect des règles, les points non utilisés peuvent être annulés sans compensation.',
                  ),

                  _buildSection(
                    '6. Données personnelles',
                    'Novopharma / Medsource collecte et traite les données personnelles des utilisateurs (nom, prénom, coordonnées professionnelles, données de performance, etc.) dans le respect du Règlement Général sur la Protection des Données (RGPD) et de la législation en vigueur.\n\nLes utilisateurs disposent d\'un droit d\'accès, de rectification, de suppression et de portabilité de leurs données en contactant :\ns.hamza@novopharma.tn',
                  ),

                  _buildSection(
                    '7. Propriété intellectuelle',
                    'L\'ensemble des éléments de l\'Application MyChallenge (logos, textes, graphismes, bases de données, interface, etc.) est la propriété exclusive de Novopharma ou Medsource.\n\nToute reproduction, diffusion, modification ou exploitation, totale ou partielle, sans autorisation écrite, est strictement interdite.',
                  ),

                  _buildSection(
                    '8. Responsabilité / Clause de non-responsabilité',
                    'L\'Application est fournie « en l\'état », sans garantie d\'exactitude, d\'exhaustivité ou de disponibilité continue.\n\nNovopharma / Medsource ne sauraient être tenues responsables :\n- d\'un usage non conforme ou inapproprié de l\'Application,\n- d\'une interruption temporaire de service,\n- d\'erreurs ou omissions dans les données saisies ou transmises par les utilisateurs.\n\nLes informations diffusées via l\'Application sont à titre indicatif et ne remplacent en aucun cas le diagnostic, le suivi médical , ni la prescription réalisés par un médecin.\n\nChaque utilisateur est seul responsable :\n- des conseils ou informations qu\'il formule,\n- de leur conformité à la réglementation pharmaceutique en vigueur,\n- et de leur adéquation avec le diagnostic et la prescription médicale du patient.',
                  ),

                  _buildSection(
                    '9. Suspension ou suppression du compte',
                    'Novopharma / Medsource se réservent le droit de suspendre ou supprimer un compte utilisateur en cas de fraude, tentative de manipulation du système de points, ou non-respect des présentes CGU.',
                  ),

                  _buildSection(
                    '10. Modification des CGU',
                    'Les présentes CGU peuvent être modifiées à tout moment par Novopharma / Medsource.\n\nLes utilisateurs seront informés de toute mise à jour via MyChallenge ou par courrier électronique.\n\nLa poursuite de l\'utilisation de l\'Application après notification vaut acceptation des nouvelles conditions.',
                  ),

                  _buildSection(
                    '11. Loi applicable et juridiction compétente',
                    'Les présentes CGU sont soumises au droit tunisien.\n\nTout litige relatif à leur interprétation ou à leur exécution sera de la compétence exclusive des tribunaux du ressort de Tunis, sauf disposition légale impérative contraire.',
                  ),

                  const SizedBox(height: 24),

                  // Last updated
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1F9BD1).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(
                                Icons.update,
                                color: Color(0xFF1F9BD1),
                                size: 16,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Dernière mise à jour',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF102132),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Ces conditions générales d\'utilisation ont été mises à jour le 12 novembre 2025.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom action
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: Colors.grey[200]!, width: 1),
              ),
            ),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1F9BD1),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_outline, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'J\'ai lu et compris',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [Color(0xFF1F9BD1), Color(0xFF1887B8)],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: const TextStyle(
              fontSize: 14,
              height: 1.6,
              color: Color(0xFF374151),
            ),
          ),
        ],
      ),
    );
  }
}
