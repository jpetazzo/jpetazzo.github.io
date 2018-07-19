---
layout: post
title: "Les conteneurs : par où commencer ?"
---

Depuis quelques années, l'industrie du logiciel parle énormément des
*containers* ; notamment de deux projets phares de cet écosystème :
Docker et Kubernetes. Cet article donne une introduction de haut niveau
(à quoi servent les conteneurs?) et donne un exemple de feuille de route
que vous pouvez utiliser dans votre "voyage" pour adopter cette
technologie et en tirer le meilleur parti.

> Avant de commencer, une petite page de pub pour le sponsor de
> ce blog, c'est-à-dire moi-même ! En septembre à Paris, nous
> organisons une formation de deux jours sur les containers et
> Kubernetes. Vous pourrez trouver Le programme détaillé, les tarifs,
> et toutes les informations nécessaires
> [ici](https://enix.io/fr/services/formation/deployer-ses-applications-avec-kubernetes/)!

Si vous connaissez déjà le principe des conteneurs et voulez voir
la feuille de route que je propose, c'est [par là](#ok-par-où-commencer-) !

![it's dangerous to deploy alone, take this](/assets/it-s-dangerous-to-deploy-alone.png)

*If you can't read French and wonder what this post is about: it gives
a high level intro to containers, as well as a roadmap for someone who
wants to leverage them to ship and deploy applications faster and more
reliably.*


## Pourquoi se mettre aux conteneurs ?

Si vous êtes familiers avec la problématique du *déploiement*, je vous
invite à passer directement à la [section suivante](#déployer-avec-les-conteneurs).


### Le quoi ? Le déploiement ?

Le déploiement est un défi technique de l'informatique moderne.
Pour clarifier : on parle ici du déploiement du code
applicatif sur un (ou plusieurs!) serveurs. En effet, on édite rarement
directement le code qui tourne sur les serveurs de production ! On travaille
généralement sur une copie locale. Puis, le code de l'application passe par
une série d'étapes plus ou moins nombreuses et plus ou moins complexes
avant de se retrouver en production — et accédé par nos utilisateurs.

Dans son expression la plus simple, le déploiement d'un site web statique
se résume à copier les fichiers du site sur un serveur. On faisait ça dans
les années 90 avec le protocole FTP. De nos jours, on est beaucoup plus
exigeants : même si un site reste purement statique, c'est une bonne idée
de le servir via un CDN (pour offrir des performances optimales depuis
n'importe quel point du globe). De plus, on veut être capable de faire un *rollback*,
c'est-à-dire un retour sur une version précédente en cas d'erreur
(pour enlever un contenu litigieux, ou si on a fait une boulette et
malencontreusement effacé toute une section du site). Du coup, des services
sophistiqués comme [Netlify](https://www.netlify.com/) sont apparus,
permettant d'avoir des fonctionalités modernes tout en gardant la
simplicité historique de "je copie mes fichiers sur le serveur et pouf
c'est fini!" (Netlify est utilisé, par exemple, pour la [documentation
de Kubernetes](https://github.com/kubernetes/website).)

Mais la majorité des applications web modernes nécessitent des opérations
beaucoup plus complexes qu'un simple transfert de fichier. Certains langages
comme Java ou Go sont compilés. Il faut s'assurer que la bonne version
du compilateur (ou de l'interpréteur, pour les autres langages) est utilisée. Quasiment tous les
projets modernes ont des dépendances logicielles, et là aussi, il faut
prendre soin d'utiliser les bonnes versions. Ces versions sont presque
toujours différentes entre l'environnement serveur et celui de développement.
Et ceci n'est que la partie visible de l'iceberg !

De plus, le déploiement ne concerne pas que les applications web, mais aussi
tous les *backends* des applications mobiles.
Quant aux applications traditionnelles
(de bureautique ou ludiques) elles ont de plus en plus souvent besoin,
elles aussi, d'un *backend* pour fonctionner.

En théorie, il existe (depuis longtemps!) beaucoup d'outils solides
permettant de résoudre ces challenges :
- des *package managers* (comme npm, rpm, pip, dpkg...),
- des outils de *configuration management* (comme Ansible, Chef, Puppet, Salt...),
- des bonnes pratiques telles que la génération de *golden images*, le
  *blue/green deployment*, etc.

En réalité, ces outils et ces pratiques sont souvent difficiles à prendre
en main. Cela peut déboucher sur deux situations : des structures modestes
qui n'ont pas les moyens de mettre en place ces méthodes (par manque
d'expertise en interne), et des structures plus fortunées, dans lesquelles
des effectifs dédiés s'en occupent. Mais cela crée alors un fossé entre
les équipes de développement et les équipes en charge du déploiement
(les "ops"), et ce fossé empêche de s'engager dans une démarche "devops"
(où les développeurs sont capables de déployer leur code de manière
autonome et fiable).

C'est là que les *containers* entrent en scène.

(Vous aurez peut-être remarqué que j'utilise tantôt le mot anglais
*container* et tantôt le mot français conteneur. C'est juste pour ne pas
faire de jaloux!☺)


### Déployer avec les conteneurs

Les conteneurs permettent de résoudre une grande partie des problèmes
liés au déploiement. Comment ? Plutôt que de partir dans des considérations
techniques sur les *namespaces*, les *control groups*, et le *copy on write*,
je vais partager avec vous mon explication favorite. Pour la comprendre,
il vous suffit d'avoir un *smartphone* sur lequel vous avez installé des
applications.

Précisément, lorsque vous avez installé ces applications (que ça soit via
le "store" d'Apple, celui de Google, ou d'un autre constructeur), tout
ce que vous avez eu à faire, c'est appuyer sur un bouton. L'application
s'est téléchargée toute seule, ainsi que toutes ses dépendances. Et ensuite,
elle s'est lancée sans problème. (En principe!)

Les conteneurs permettent un résultat similaire pour les applications
qui s'exécutent non pas sur un téléphone mobile, mais sur un serveur
(ou une machine de développement). En tant qu'administrateur système,
si je veux lancer un conteneur sur un serveur, j'effectue une opération
très simple (l'équivalent du clic dans l'app store), et quelques instants
plus tard, le code dans le conteneur se lance. Les applications
mobiles font abstraction du modèle exact de téléphone, de la version
d'iOS ou Android installée, et des autres applications présentes. De la
même manière, les conteneurs font abstraction de mon modèle de serveur
(constructeur si c'est une machine physique, hyperviseur si c'est une
machine virtuelle), de la version de Linux (voire Windows) installée,
et des autres programmes tournant sur le serveur.

À partir de là, les conteneurs "plaisent" à (au moins) deux publics.

Premièrement, les développeurs qui galèrent avec leur poste de travail.
Annie travaille sur une machine sous Debian GNU/Linux, Bernard sur
un Mac, Christophe sur un PC sous Windows 7, et Diane sous Windows 10.
Si vous trouvez cette disparité exagérée, pensez aux structures qui
font appel à des consultant·e·s, par exemple. Ou bien au fait qu'au
fil du temps, les versions de Java, PHP, Python, etc. vont fortement
diverger d'un poste à l'autre.

Les conteneurs permettent d'avoir un environnement de développement
cohérent. Cela fonctionne (et améliore le travail de l'équipe) même
si les conteneurs sont limités au poste de travail (et ne sont pas
utilisés sur les serveurs).
Annie, Bernard, Christophe et Diane ont peut-être chacun
un système d'exploitation différent, mais s'ils utilisent Docker
(et les déclinaisons Docker for Mac et Docker for Windows) ils
peuvent tous développer très simplement dans des conteneurs Ubuntu
ou CentOS (si c'est la distribution utilisée sur les serveurs).

Lorsqu'une nouvelle recrue rejoint l'équipe, elle sera opérationnelle
beaucoup plus rapidement ; idem lorsqu'une personne (interne ou externe
à l'entreprise) doit intervenir ponctuellement : fini le temps perdu
à installer des dizaines de dépendances, s'assurer que toutes les
versions sont correctes, etc.

Deuxièmement, les conteneurs peuvent aussi rendre service aux
équipes qui s'occupent de la "mise en production" — soit le fameux
déploiement évoqué au début de cet article. Au lieu de nécessiter
l'installation (et parfois la mise à jour) de dizaines voire
centaines de dépendances, il suffit de lancer un conteneur.
Mieux : en cas de problème, il est très facile de revenir à la
version précédente. Un peu comme si, avec une application mobile,
vous aviez la possibilité d'installer deux versions l'une à côté
de l'autre. La nouvelle mise à jour ne fonctionne pas, ou ne vous
plaît pas ? Pas de problème : lancez l'ancienne version. Problème
réglé !

*D'accord, mais fabriquer un conteneur ... C'est compliqué, non ?*

C'était difficile jusqu'à 2013. Puis, en 2013, Docker a rendu
les conteneurs (qui existaient depuis le début des années 2000)
accessibles au plus grand nombre. Résultat : aujourd'hui,
écrire un Dockerfile (la recette permettant
de construire une image de conteneur) est beaucoup plus facile que
fabriquer un paquet pour un *package manager* ou prendre en main
un outil de *configuration management*. C'est ça qui
a fait exploser la popularité de Docker et des conteneurs.


## OK, par où commencer ?

En 7 ans d'expérience chez Docker Inc., j'ai eu l'honneur d'aider des
équipes de toutes sortes à prendre en main les conteneurs (avec Docker
ou avec d'autres outils). Je vais donc vous livrer une recette que
j'ai vue fonctionner de nombreuses fois, dans des structures de toutes
tailles (quelques personnes ou quelques milliers de personnes),
pour du web, du mobile, du machine learning ...


**Étape 1 :** "containeriser" un premier service. Je dis *service*
car ce n'est pas nécessaire de prendre une application dans son
intégralité. On peut commencer par un petit composant au sein d'une
application plus grosse.
Typiquement, on prendra un service ayant de nombreuses
dépendances logicielles et un processus de *build* capricieux, car
c'est précisément le genre de scenario où l'on aura le plus grand
progrès visible !

**Étape 2 :** "containeriser" les autres services de l'application,
et exprimer l'intégralité de la pile applicative avec un outil
comme Docker Compose. Cela va permettre d'uniformiser le processus
de développement pour l'application dans son entier. À l'issue de
cette phase, vous serez à même de faire tourner cette application
de manière identique sur n'importe quel poste de travail (macOS,
Windows, Linux) en un clin d'œil.

**Étape 3 :** mettre en place un *pipeline* de CI/CD (intégration
continue / déploiement continu) pour améliorer la qualité du code.
Il y a là deux initiatives distinctes :

- L'intégration continue — à chaque fois qu'une modification est
  enregistrée dans le dépôt de code (après chaque "commit"),
  des tests unitaires sont
  automatiquement exécutés, permettant de détecter des régressions
  éventuelles avant qu'elles n'affectent vos utilisateurs.
- Le déploiement continu — à chaque fois qu'une modification est
  enregistrée dans le dépôt de code, la nouvelle version du
  code est déployée automatiquement dans un environnement de
  qualification (ou pré-production). Cela permet au développeur
  (ou à une équipe qualité) d'effectuer des tests fonctionnels
  sur une version "live" de l'application, et encore une fois,
  de détecter des problèmes avant vos utilisateurs.

Ces deux initiatives nécessitent de pouvoir créer à la volée des
environnements éphémères. Pas question de demander à
un administrateur système de provisionner un ensemble de machines
virtuelles à chaque fois qu'on doit lancer un test ! Les conteneurs sont
particulièrement adaptés, car créer un conteneur à partir
d'un script (par exemple) est à la fois très simple et très rapide.

**Étape 4 :** étendre le processus de déploiement continu au domaine
de la production. Cela signifie que chaque modification du code
passe par l'étape CI/CD, et si les tests passent avec succès,
les conteneurs sont installés sur les serveurs de production,
prêts à démarrer. La mise en production peut alors se faire
très rapidement (le démarrage des nouveaux conteneurs et l'arrêt
des anciens prend typiquement quelques secondes), voire complètement
automatiquement si les tests automatiques sont suffisamment exhaustifs.
Cette dernière étape fait généralement appel à un ordonnanceur comme
Kubernetes, Mesos, ou Swarm.


**Chaque étape apporte des bénéfices concrets et tangibles.**
Vous n'avez pas besoin de dérouler l'intégralité du plan avant
de voir des résultats ! Par exemple, vous pouvez commencer par les
premières étapes,
constater par vous-même les gains effectués, puis continuer à votre
rythme, selon l'évolution de vos besoins.


### Se former, seul ou accompagné

La communauté Docker est extrêmement riche en tutoriels divers
pour démarrer et aller plus loin. Je recommande particulièrement
les "labs" disponibles sur [training.play-with-docker.com](https://training.play-with-docker.com/).

Si vous préférez être formé en personne, c'est aussi possible !
Publicité bien ordonnée commence par soi-même : en septembre, j'organise
une formation à Paris, vous permettant de sérieusement prendre en
main Kubernetes en deux jours. Si vous voulez consulter le programme
détaillé ou vous inscrire, c'est [par ici](
https://enix.io/fr/services/formation/deployer-ses-applications-avec-kubernetes/).

Si vous voulez vous faire une idée de la qualité du contenu de
cette formations, vous pouvez consulter des vidéos et slides de
formations précédentes, par exemple :

- [journée d'introduction à Docker](https://www.youtube.com/playlist?list=PLBAFXs0YjviLgqTum8MkspG_8VzGl6C07)
- [demi-journée d'introduction à Kubernetes](https://www.youtube.com/playlist?list=PLBAFXs0YjviLrsyydCzxWrIP_1-wkcSHS)

Ces vidéos sont en anglais, mais les formations que je vous propose à
Paris en septembre sont en français (le support de formation, lui, reste en anglais).

Vous pouvez trouver d'autres vidéos, ainsi qu'une collection de supports (slides etc.)
sur http://container.training/. Cela vous permettra de juger au mieux
si ces formations sont adaptées à votre besoin !

