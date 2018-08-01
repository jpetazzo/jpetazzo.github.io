---
layout: post
title: "Dérisquer son infrastructure avec les conteneurs"
---

On parle souvent des conteneurs comme un moyen d'accélérer les
cycles de développement, mais ils permettent aussi de dérisquer
(ou réduire les risques, si le néologisme vous fait grincer
des dents ☺) les opérations de déploiement. Comment donc ?
Grâce à un *pattern* sûrement familier à certain·e·s d'entre
vous : les « infrastructures immutables ». Nous allons voir
comment ce *pattern* réduit les risques, et comment les conteneurs
le rendent accessible à des structures de tailles et de compétences
variées.

> Avant de commencer, une petite page de pub pour le sponsor de
> ce blog, c'est-à-dire moi-même ! En septembre à Paris, nous
> organisons avec Enix une formation de deux jours sur les conteneurs et
> Kubernetes. Vous pourrez trouver le programme détaillé, les tarifs,
> et toutes les informations nécessaires
> [ici](https://enix.io/fr/services/formation/deployer-ses-applications-avec-kubernetes/) !

*If you can't read French and wonder what this post is about: it
explains how containers can be used to implement immutable
infrastructures, thus considerably reducing the risks associated
with application deployment. If you understand English and want
to know more about this, you can check e.g. [this talk](
https://www.infoq.com/presentations/immutable-servers-docker)
that I gave at QCON a few years ago. Also, in september, I will
be delivering a [two days Kubernetes training in Paris (in French)](
https://enix.io/fr/services/formation/deployer-ses-applications-avec-kubernetes/)
and another [two days Kubernetes training iN New York (in English)](
https://conferences.oreilly.com/velocity/vl-ny/public/schedule/detail/69875
). Thank you!*


## Une brève histoire du déploiement

J'ai déjà [parlé du déploiement dans un article précédent](
/2018/03/28/containers-par-ou-commencer/#le-quoi--le-d%C3%A9ploiement-),
en soulignant les facilités apportées par les conteneurs.
Grâce aux conteneurs, au lieu de créer des paquetages multiples
(deb, rpm, npm, pip, jar, etc.) il suffit d'apprendre à
écrire un Dockerfile pour être capable de livrer n'importe quel
composant logiciel. Fini les problèmes de dépendances, les
différences de versions entre le dev' et la prod' : vous avez
sûrement déjà entendu ces arguments pas mal de fois !

Mais les conteneurs nous aident aussi à réduire les risques.
Plus précisément, je souhaite aujourd'hui traiter de la question suivante :

**Que fait-on quand le déploiement se passe mal ?**

Il peut y avoir plein de bonnes mauvaises raisons pour que ça
arrive : un bug qui passe au travers des mailles de la QA
(que celle-ci soit manuelle ou automatique), une régression
des performances, mais aussi un problème lié au processus de
déploiement lui-même.

Donc, que faire ? Et en quoi les conteneurs vont nous aider ?


### Machine arrière, toute

Le premier réflexe quand on se rend compte qu'on a déployé
une mauvaise version en production, c'est de revenir en arrière,
c'est-à-dire redéployer la version précédente.

Si on a un processus de déploiement bien rodé et qu'on a
encore la version précédente du code, c'est en théorie assez facile.
Il suffit de s'imposer une certaine discipline ; par exemple
« notre code doit toujours être dans un dépôt *git*, et
tout déploiement doit se faire à partir d'un *tag* ».
Dans ce cas, pour revenir en arrière, on reprend le *tag*
précédent et on redéploie.

*Note : si votre code n'est pas dans un système de contrôle de source,
ou que vous n'utilisez pas encore de branches ou de tags, je
vous conseille de commencer par là ; vous avez encore plus à y gagner !*


### La théorie ... et la pratique

Malheureusement, parfois, il y a un hic. Par exemple,
la nouvelle version du code nécessite la mise à jour
d'un autre composant, et la nouvelle version de ce
composant n'est pas compatible avec l'ancienne version
du code. Ou bien, dans le même ordre d'idée, ce n'est pas
notre code qui a un problème, mais une de ces dépendances
qui a été mise à jour lors du déploiement. Quand on fait
notre retour en arrière du code, il faut alors aussi
penser à faire un retour en arrière des dépendances.
Or, ça n'est pas toujours facile, ou même possible !
Si on n'a pas pensé à lister explicitement les versions
de toutes les dépendances qu'on utilises (et, récursivement,
les dépendances de ces dépendances et ainsi de suite),
c'est difficile de savoir ce qui était installé auparavant.
Avec un peu de chance, ça peut se trouver dans les *logs*
du déploiement:

```
$ pip install 'Flask>=1.0'
Collecting Flask>=1.0
...
Installing collected packages: Flask
  Found existing installation: Flask 0.12.4
    Uninstalling Flask-0.12.4:
      Successfully uninstalled Flask-0.12.4
Successfully installed Flask-1.0.2
```

Mais il faut encore que les anciennes versions de ces
dépendances soient encore disponibles. Dans le cas de
`Flask` ci-dessus, tout va bien, car les [anciennes
versions sont archivées dans PyPI](
https://pypi.org/project/Flask/#history), mais ce
n'est pas forcément le cas partout.

Il peut aussi arriver
que le processus de déploiement échoue, mais uniquement
sur certains serveurs.
Par exemple, le déploiement peut nécessiter beaucoup
d'espace disque : parce qu'ils télécharge et transforme
des gros *assets*, ou parce qu'il compile des dépendances
significatives comme `ffmpeg`. Ces opérations marchent
toujours sur un serveur fraîchement installé (où le disque
est vide) mais vont échouer si on tente
un déploiement sur un serveur ayant davantage d'heures
de vol, et où les disques sont davantage remplis.

Et si on est particulièrement malchanceux, on peut aussi
« casser » les serveurs — j'entends pas là, entraîner
un *crash* du serveur, ou bien (plus subtilement) empêcher
malencontreusement les futures connexions au serveur
(et donc nous empêcher de corriger le problème de déploiement).

Heureusement, tous les problèmes que je viens de décrire
sont rares. Malheureusement, ils finissent tous par nous arriver
un jour ou l'autre. Et le jour où ça arrive, trouver
la source du problème n'est pas toujours facile ou rapide.
On veut revenir à la version précédente dans les délais les
plus brefs, et sans avoir l'impression de jouer un coup de poker.

C'est là que les conteneurs (et les infrastructures immutables
en général) vont nous sauver la mise.


## Infrastructures immutables

Le principe de l'infrastructure immutable, c'est qu'on ne
fait jamais de modification sur un serveur. Quand on veut
déployer une nouvelle version, on prend un nouveau serveur,
on installe la nouvelle version sur ce nouveau serveur, puis
on remplace l'ancien serveur par le nouveau.

Du coup, quand on veut revenir en arrière, il suffit de
ressortir l'ancien serveur du placard et de le remettre en
marche.

Le concept est simple ; son implémentation l'est moins.

Si on utilise des machines physiques, le
processus est particulièrement lourd. On peut employer des techniques
comme le [PXE](https://en.wikipedia.org/wiki/Preboot_Execution_Environment)
pour provisionner automatiquement des nouveaux serveurs
au travers de leur connexion réseau, sans intervention physique).
Mais c'est lent, cher,
et ça demande des compétences qui ne courent pas les rues.

Avec des machines virtuelles, c'est une stratégie déjà plus
réaliste. On peut facilement démarrer et déployer des
machines virtuelles de manière automatique : tous les
*clouds* publics ou privés dignes de ce nom offrent une API
et/ou une CLI permettant d'écrire des scripts pour lancer des
serveurs.

D'autre part, des outils
comme [Packer de HashiCorp](https://www.packer.io/)
permettent de créer des « golden images » de serveurs ; par exemple,
si on utilise AWS, on peut utiliser Packer afin de créer
automatiquement une AMI (image de machine virtuelle) à chaque
fois qu'on veut réaliser un déploiement. Pour mettre en production,
on lance des machines virtuelles avec l'image qu'on vient de
créer ; et pour revenir en arrière, on relance des machines
virtuelles avec la version précédente.


### *Move fast and break things*

À partir de là, on peut faire encore mieux. Quand on passe
en production sur les nouveaux serveurs, au lieu d'arrêter
les anciens, on peut les écarter. La manière la plus radicale
est de les débrancher du réseau ; mais on peut aussi (de manière
un peu plus fine) les sortir des *load balancers* (ou les
déconnecter des *message queues* dans le cas de *workers*
asynchrones). Puis, quand on veut faire un retour en arrière,
il suffit de rebrancher le réseau (ou remettre les *backends*
dans le *load balancer*) : c'est très facile, très rapide,
et aussi très fiable.

Cette idée permet d'implémenter deux techniques particulières :
le *blue green deployment* et les *canary releases*.

Dans un [*blue green deployment*](
https://docs.cloudfoundry.org/devguide/deploy-apps/blue-green.html
), lorsqu'on déploie une nouvelle
version, on déploie un nouvel ensemble de serveurs (l'ensemble
*green*) pour remplacer l'ancien (le *blue*) ; puis, on bascule
tout le trafic d'une *stack* à l'autre. Un peu comme si on changeait
d'un seul coup le signal d'aiguillage d'une voie ferrée, mais
au niveau de nos *load balancers*. En cas de problème, tout
ce qu'il y a à faire, c'est rebasculer vers l'ancienne *stack*.

Une [*canary release*](http://featureflags.io/canary-release/)
est une *release* qui n'est exposée qu'à un petit nombre
d'utilisateurs. Au lieu de faire basculer l'intégralité
du trafic sur la nouvelle version, on n'en fait passer qu'une partie.
Selon les cas, ça peut être une fraction des requêtes, ou bien
seulement les requêtes de certains utilisateurs, par exemple.
Puis, on observe attentivement ce qui se passe pour ces requêtes
(ou ces utilisateurs). Si tout va bien, on peut faire passer
tout le trafic sur la nouvelle version (ou même augmenter de manière
progressive). Si nos métriques nous indiquent que les taux
d'erreur ou la latence sont plus élevés sur la nouvelle version,
ou bien que les utilisateurs nous remontent des problèmes,
on revient à la version originale — et ce faisant, on n'a
impacté qu'une toute petite fraction du trafic (ou des utilisateurs) ;
la plupart n'ont même pas vu le problème survenir.

(Le nom *canary release* vient des canaris qui étaient utilisés
dans les mines de charbon pour détecter les gaz toxiques comme
le monoxyde de carbone : les mineurs transportaient un canari
dans une cage, et si la concentration de gaz toxique devenait
trop élevée, le pauvre canari tournait de ĺ'œil ; mais comme
les canaris sont plus sensibles que les humains, cela arrivait
avant que les mineurs ne soient affectés, et leur laissait donc
le temps de faire demi-tour pour revenir en sécurité.)

Ces procédés ont été largement décrits par des organisations
[comme Netflix](https://medium.com/netflix-techblog/how-we-build-code-at-netflix-c5d9bd727f15) par exemple,
[ou encore Facebook](https://code.fb.com/web/rapid-release-at-massive-scale/).
C'est d'ailleurs comme ça que Facebook a pu
[abandonner le slogan « move fast and break things »](
https://mashable.com/2014/04/30/facebooks-new-mantra-move-fast-with-stability/),
et ne garder que la partie « move fast ».

Le problème de ces techniques, c'est qu'elles nécessitent
souvent un outillage assez lourd, voire des équipes entières
dont la mission est de fournir une plateforme de développement
au reste de l'organisation. Netflix emploie plus de 5000
personnes, Facebook plus de 25000. Est-ce que des organisations
de taille plus modeste peuvent se permettre d'adopter des
techniques aussi efficaces ?

*Spoiler alert : oui !*


## Les conteneurs à la rescousse

Si vous avez utilisé Docker (même de manière très superficielle),
il y a des grandes chances que vous ayiez déjà les compétences
nécessaires pour savoir faire un tel *rollback*.

Si vous faites attention à appliquer un *tag* différent à chaque
fois que vous construisez une image, toutes vos images précédentes
restent disponibles en cas de problème.

Par exemple :

```
# On construit l'image pour notre appli ...
docker build -t monappli:v1.0
# ... Et on la lance.
docker run -d -p 80:80 --name monappli monappli:v1.0
# ... On modifie le code, et on re-build ...
docker build -t monappli:v1.1
# ... Puis on stoppe l'ancienne version ...
docker rm -f monappli
# ... Et on lance la nouvelle.
docker run -d -p 80:80 monappli:v1.1
# ... On se rend compte qu'on a un problème :
# ... Son stoppe la version actuelle ...
docker rm -f monappli
# ... Et on relance l'ancienne.
docker run -d -p 80:80 --name monappli monappli:v1.0
# ... Et voilà !
```

Ces commandes (`docker build`/`run`/`rm`) sont des commandes
de base de Docker. Elles suffisent pour être capable de réaliser
un *rollback* fiable et extrêmement rapide. Pas besoin d'apprendre
Packer, Terraform (même si ce sont d'excellents outils!), ou
de peaufiner des scripts manipulant la CLI ou l'API de votre
*cloud*.

Si vous voulez davantage de détails, vous pouvez consulter
la version gratuite de
[notre support de formation « introduction aux conteneurs »](
http://container.training/intro-selfpaced.yml.html#toc-local-development-workflow-with-docker
) (ce lien vous emmènera directement au chapitre correspondant).


### Et l'orchestration dans tout ça ?

L'exemple ci-dessus met en jeu un seul conteneur déployé sur un serveur
unique. Si votre application tourne sur un *cluster* (ce qui sera le
cas tôt ou tard, espérons-le, si votre application rencontre le succès
et le trafic qui va avec), les choses se compliquent.

Faut-il lancer les commandes ci-dessus sur tous nos serveurs ?
En parallèle, séquentiellement ? On pourrait. Ou bien, on pourrait
laisser un orchestrateur comme Kubernetes s'en occuper pour nous.

Avec Kubernetes, passer à la version `v1.1` de notre appli devient :

```
kubectl set image monappli monappli=monappli:v1.1
```

Cette commande va progressivement remplacer les conteneurs de
l'application de manière à utiliser l'image `monappli:v1.1`.
« Progressivement », c'est-à-dire en s'assurant de ne jamais
avoir :
- plus d'un conteneur hors service (jusqu'à Kubernetes 1.10),
- plus de 25% du total hors service (à partir de Kubernetes 1.11).

(Bien sûr, ces nombres ne sont que les valeurs par défaut ;
les valeurs exactes ­— en absolu ou en proportion du
total — peuvent être ajustées pour chaque déploiement.)

Quant au *rollback*, vous l'avez probablement deviné, il se fait
avec :

```
kubectl set image monappli monappli=monappli:v1.0
```

C'est tout !

Si vous voulez davantage de détails, nous avons aussi une
version gratuite de notre [support de formation Kubernetes](
http://container.training/kube-selfpaced.yml.html#toc-rolling-updates)
(là aussi, le lien vous emmène directement vers le chapitre en question).


### Les avantages des conteneurs

Deployer une image de conteneur va plus
vite que déployer une image de machine virtuelle. Mécaniquement,
parce qu'une image de conteneur embarque moins de composants
qu'une image de machine virtuelle. Ça ira donc plus vite
de la construire, mais aussi la déployer sur les serveurs.
Et si vous tirez parti du système de cache de
Docker, construire une nouvelle image est une affaire de
*secondes*, idem pour son déploiement sur les serveurs
à travers une *registry* — même pour une grosse application,
grâce au système de *layers* employé par Docker.

Lancer un conteneur est aussi plus rapide que lancer
une machine virtuelle.

Enfin, de plus en plus de
fournisseurs *cloud* proposent une tarification à la
minute dès la première minute, mais il y a encore beaucoup
de plateformes qui facturent à l'heure ; du coup,
chaque déploiement coûte un peu d'argent pour chaque
nouveau serveur lancé.

Bilan : utiliser des conteneurs, c'est non seulement plus facile,
mais aussi plus rapide et moins cher.


## Bien démarrer avec Docker et Kubernetes

En ce qui concerne Docker,
la communauté est extrêmement riche en tutoriels divers
pour démarrer tout comme aller plus loin. Je recommande particulièrement
les « labs » disponibles sur [training.play-with-docker.com](https://training.play-with-docker.com/).

Et en ce qui concerne Kubernetes, idem, vous trouverez de
nombreux tutoriels et formations, y compris en français.

J'en profite donc pour mentionner une formation que nous organisons avec Enix en septembre à Paris,
vous permettant de sérieusement prendre en
main Kubernetes en deux jours. **Si vous voulez consulter le programme
détaillé ou vous inscrire, c'est [par ici](
https://enix.io/fr/services/formation/deployer-ses-applications-avec-kubernetes/) !**

Si vous voulez vous faire une idée de la qualité du contenu de
cette formations, vous pouvez consulter des vidéos et slides de
formations précédentes, par exemple cette
[journée d'introduction à Docker](https://www.youtube.com/playlist?list=PLBAFXs0YjviLgqTum8MkspG_8VzGl6C07)
ou cette [demi-journée d'introduction à Kubernetes](https://www.youtube.com/playlist?list=PLBAFXs0YjviLrsyydCzxWrIP_1-wkcSHS).

Ces vidéos sont en anglais, mais les formations proposées à
Paris en septembre sont en français (le support de formation, lui, reste en anglais).

Vous pouvez trouver d'autres vidéos, ainsi qu'une collection de supports (slides etc.)
sur [http://container.training/](http://container.training).
Cela vous permettra de juger au mieux
si ces formations sont adaptées à votre besoin !
