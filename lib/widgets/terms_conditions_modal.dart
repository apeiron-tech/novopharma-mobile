import 'package:flutter/material.dart';
import 'package:novopharma/design/design.dart';

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
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.9,
      child: Glass(
        blur: Glass.frost,
        shadow: false,
        tint: Colors.white,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadii.xl),
        ),
        // The sheet opens over the aurora. A second wash of white keeps the
        // frosted pane light enough for dark text all the way down.
        child: ColoredBox(
          color: Colors.white.withValues(alpha: 0.55),
          child: Column(
            children: [
              // Drag indicator
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 2),
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.ink.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(5),
                ),
              ),

              // Header with close button
              _buildHeader(context),

              // Content
              Expanded(child: _buildContent()),

              // Bottom action
              _buildAction(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final closeLabel = MaterialLocalizations.of(context).closeButtonTooltip;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 14),
      child: Row(
        children: [
          const BlisterIcon(
            icon: Icons.description_rounded,
            size: 46,
            glow: false,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Conditions Générales d\'Utilisation (CGU)',
                  style: AppText.display(size: 19),
                ),
                const SizedBox(height: 3),
                Text(
                  'Application MyChallenge',
                  style: AppText.label(
                    size: 13.5,
                    color: AppColors.indigoDeep,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Tooltip(
            message: closeLabel,
            child: Pressable(
              onTap: () => Navigator.pop(context),
              pressedScale: 0.9,
              semanticLabel: closeLabel,
              child: SizedBox.square(
                dimension: 44,
                child: Center(
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.ink.withValues(alpha: 0.08),
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      color: AppColors.text,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The text itself, on a brighter page set into the sheet.
  Widget _buildContent() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 22, 18, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection(
              '1. Objet',
              '''Les présentes Conditions Générales d'Utilisation (ci-après les « CGU ») ont pour objet de définir les modalités d'accès et d'utilisation de l'application d'incentive MyChallenge (ci-après l'« Application »), mise à disposition par Novopharma ou sa filiale Medsource (ci-après « l'Entreprise »), au profit des préparateurs et préparatrices en pharmacie participant au programme de motivation commerciale.

L'Application MyChallenge permet aux utilisateurs de suivre leurs performances, cumuler des points, consulter leurs récompenses et accéder à diverses informations commerciales dans le cadre des campagnes d'incentive organisées par l'Entreprise.

Elle leur offre également la possibilité de bénéficier de formations régulières pour améliorer leurs connaissances et de renforcer leur expertise pour mieux conseiller nos marques.''',
            ),

            _buildSection(
              '2. Acceptation des CGU',
              'L\'accès et l\'utilisation de MyChallenge impliquent l\'acceptation pleine et entière des présentes CGU.\n\nTout utilisateur qui n\'accepte pas ces conditions doit s\'abstenir d\'utiliser l\'Application.',
            ),

            _buildSection(
              '3. Accès à l\'Application',
              '''L'Accès à MyChallenge est réservé aux personnes autorisées par Novopharma ou Medsource, dans le cadre d'un partenariat ou d'une activité professionnelle avec une pharmacie participante.

L'inscription et l'utilisation de l'Application par un préparateur ou une préparatrice sont soumises à l'accord préalable du pharmacien titulaire ou du pharmacien responsable de la pharmacie concernée, formalisé par une signature.

L'accès peut être retiré à tout moment :
- en cas de non-respect des présentes CGU ou des règles du programme,
- ou à la demande du pharmacien titulaire ou responsable de la pharmacie participante.''',
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

            // Last updated
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(AppRadii.md),
                border: Border.all(color: AppColors.line),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const TintIcon(icon: Icons.update_rounded, size: 36),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Dernière mise à jour',
                          style: AppText.body(
                            size: 14,
                            weight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Ces conditions générales d\'utilisation ont été mises à jour le 12 novembre 2025.',
                          style: AppText.body(
                            size: 13,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAction(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
        child: PrimaryButton(
          label: 'J\'ai lu et compris',
          icon: Icons.check_circle_outline_rounded,
          onPressed: () => Navigator.pop(context),
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppText.display(size: 18, color: AppColors.indigoDeep),
          ),
          const SizedBox(height: 10),
          Text(content, style: AppText.body(size: 14.5, height: 1.6)),
        ],
      ),
    );
  }
}
