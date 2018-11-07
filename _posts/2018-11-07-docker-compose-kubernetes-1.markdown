---
layout: post
title: "De Docker à Kubernetes en passant par Compose (1/2)"
---

Dans le monde des conteneurs, Docker est une formidable
plateforme de développement, et Kubernetes une tout
aussi formidable plateforme de production. Comment
passe-t-on de l'un à l'autre ? En particulier, si l'on
utilise Compose pour décrire son environnement de
développement, comment traduit-on ses fichiers Compose
en ressources Kubernetes ?

*If you can't read French and wonder what this post is about:
It's an overview of techniques that one can use to
transform an app described by a Compose file into a set
of Kubernetes resources.*

Cet article s'inscrit dans une série d'articles en français
parlant de Docker, Kubernetes, et des conteneurs en général.
Si vous souhaitez une introduction sur le sujet,
je vous invite à lire [« Les conteneurs : par où commencer? »](
/2018/03/28/containers-par-ou-commencer/) ;
si vous êtes plutôt du côté « ops » et que vous vous demandez
ce que Docker (ou les conteneurs en général) peut vous apporter,
je vous propose [« Dérisquer son infrastructure avec les conteneurs »](
/2018/08/01/containers-cloud-immutable-infrastructure-orchestration/).

Avant d'entrer dans le vif du sujet, un petite page de pub pour
le sponsor de ce blog (autrement dit, moi) :

{% include ad_fr_short.markdown %}


## Énoncé du problème

Pour se mettre aux conteneurs, je conseille souvent de procéder comme
suit :

- écrire un Dockerfile pour un service au sein d'une application
  afin de faire tourner ce service dans un conteneur,
- faire tourner de la même manière les autres services de cette
  application,
- écrire un fichier Compose pour l'application,
- ... pause.

Une fois à cette étape, on profite déjà des avantages des conteneurs,
car toute personne disposant de Docker sur sa machine peut lancer
l'application en tapant trois lignes :

```bash
git clone ...
cd ...
docker-compose up
```

Ensuite, on peut ajouter pas mal de belles choses : de l'intégration
continue, pourquoi pas du déploiement continu en pré-production ...

Mais un beau jour, on veut passer en production. Et dans de nombreux
cas, la production pour les conteneurs, ça sera avec Kubernetes.
On pourrait avoir un débat sur la pertinence de Mesos, Nomad,
Swarm, etc., mais dans le cas présent, je vais supposer qu'on
a choisi Kubernetes (ou bien que quelqu'un a choisi pour nous).

Comment passe-t-on de nos fichiers Compose à nos ressources Kubernetes ?

En première approche, vu de très (très) loin, ça devrait être
facile : Compose utilise du YAML, Kubernetes aussi.

![I see lots of YAML](https://pbs.twimg.com/media/Dfwl3oSW4AING2Z.jpg)

*Image originale par [Jake Likes Onions](
http://jakelikesonions.com/post/158707858999/the-future-more-of-the-present
), remixée par [@bibryam](https://twitter.com/bibryam/status/1007724498731372545).*

Le problème, c'est que le YAML de Compose et le YAML de Kubernetes
n'ont absolument rien à voir l'un avec l'autre. Pire : certains
concepts ont des significations complètement différentes. Par
exemple, dans Docker Compose, un [service](
https://docs.docker.com/get-started/part3/#about-services) est
un ensemble de conteneurs identiques (parfois placés derrière un
*load balancer*), tandis que dans Kubernetes, un [service](
https://kubernetes.io/docs/concepts/services-networking/service/)
est un mécanisme permettant d'accéder à des ressources
(par exemple des conteneurs) dont l'adresse réseau n'est pas fixe.
Lorsqu'il y a plusieurs ressources derrière un même service,
celui-ci fait aussi office de *load balancer*. Oui, c'est un
bon moyen de semer la confusion ; oui, je regrette moi aussi
que les concepteurs de Compose et de Kubernetes n'aient pas eu
l'occasion de se mettre d'accord sur le vocabulaire, mais en
attendant il faut faire avec.

Puisqu'on ne peut pas traduire notre YAML d'un coup de baguette
magique, comment faire ?

Je vais présenter trois façons de procéder, chacune avec ses avantages
et inconvénients.


## 100% Docker

Si on utilise une version à jour de Docker Desktop
(Docker Windows ou Docker Mac), on peut déployer un
Compose file sur Kubernetes de la manière suivante :

1. Dans les préférences de Docker Desktop, sélectionnez
   Kubernetes comme orchestrateur. (Si on était sur
   Swarm auparavant, il faudra peut-être une minute ou
   deux pour que les composants Kubernetes démarrent.)
2. Déployez votre application, avec la commande:
   ```bash
   docker stack deploy --compose-file docker-compose.yaml mabelleappli
   ```

C'est tout !

Pour les cas les plus simples, cela marchera directement :
Docker traduit le Compose file en ressources Kubernetes
(Deployment, Service, etc.) et nous n'aurons pas besoin de
maintenir des fichiers supplémentaires.

Mais il y a un hic : cela lance l'application sur notre
Docker Desktop. Comment faire pour qu'elle se lance sur
un cluster Kubernetes de production ?

Si on utilise Docker Enterprise Edition, on est sauvé :
UCP (Universal Control Plane) permet de faire exactement
la même chose, mais en ciblant son cluster Docker EE.
Pour rappel, Docker EE permet de faire tourner simultanément
des applications gérées par Kubernetes, et des applications
gérées par Swarm. Quand on déploie une application en
fournissant un fichier Compose, on indique quel orchestrateur
on veut utiliser, et le tour est joué.

(La [documentation d'UCP](https://docs.docker.com/ee/ucp/kubernetes/deploy-with-compose/) explique ça plus en détail. On peut
aussi consulter [cet article sur le blog de Docker](
https://blog.docker.com/2018/05/kubecon-docker-compose-and-kubernetes-with-docker-for-desktop/
).)

Cette méthode est particulièrement adaptée si on est
déjà client de Docker Enterprise Edition, ou bien si on
envisage de l'être ; car en plus d'être la plus simple du
lot, elle sera aussi la plus solide, car on bénéficiera
du support de Docker Inc. en cas d'incompatibilité.

D'accord, mais pour les gens qui n'utilisent *pas* Docker EE,
comment faire ?


## Avec des outils

Il y a plusieurs outils permettant de traduire un fichier Compose
en ressources Kubernetes. Je vais surtout m'attarder sur
[Kompose](http://kompose.io/), car il est (à mon humble avis)
le plus complet à ce jour, et le mieux documenté.

On peut utiliser Kompose de deux façons : en travaillant
directement avec vos fichiers Compose, ou bien en les traduisant
en fichiers YAML Kubernetes, qu'on déploie ensuite avec `kubectl`,
la CLI Kubernetes. (Techniquement, on n'est pas obligé d'utiliser
la CLI ; on peut utiliser ces fichiers YAML avec d'autres outils,
par exemple [WeaveWorks Flux](https://github.com/weaveworks/flux)
ou [Gitkube](https://gitkube.sh/), mais je simplifie un peu.)

Si on décide de travailler directement avec nos fichiers Compose,
on utilisera simplement `kompose` à la place de `docker-compose`
pour la plupart des commandes. Concrètement, on lancera notre
application avec `kompose up` (au lieu de `docker-compose up`),
par exemple.

Cette méthode est adaptée lorsqu'on travaille avec un grand nombre
d'applications, pour lesquelles on a déjà différents fichiers
Compose, et qu'on ne souhaite pas maintenir un deuxième jeu
de fichiers. Ou encore, lorsque nos fichiers Compose évoluent
rapidement, et qu'on veut éviter de gérer des divergences entre
nos fichiers Compose et nos fichiers Kubernetes.

Dans certains cas, la traduction effectuée par Kompose sera
imparfaite, voire ne marchera pas du tout. Par exemple, si on
utilise des volumes locaux (`docker run -v /path/to/data:/data ...`),
il faudra trouver une autre manière d'apporter ces données
dans nos conteneurs sur Kubernetes. (Par exemple, en utilisant
des [Persistent Volumes](https://kubernetes.io/docs/concepts/storage/persistent-volumes/).)
Ou bien on voudra en
profiter pour restructurer un peu l'application afin de
faire tourner ensemble le serveur web et le serveur applicatif,
au sein d'un même pod, au lieu d'en faire deux entités séparées.

En ce cas, on peut utiliser `kompose convert`, qui va nous
générer les fichiers YAML correspondant à toutes les ressources
qui auraient été créées par `kompose up`, et on peut ensuite
retoucher ces fichiers à loisir avant de les charger dans notre
cluster.

Cette méthode offre beaucoup de souplesse (puisqu'on peut
transformer le YAML à loisir avant de s'en servir), mais cela
veut aussi dire que toute modification du fichier Compose implique
de choisir s'il faut générer à nouveau (et le cas échéant, modifier)
nos ressources Kubernetes.

Si vous maintenez beaucoup d'applications, mais avec des architectures
(et des *patterns*) similaires, vous pouvez utiliser `kompose convert`
puis appliquer un post-traitement automatique aux fichiers YAML
générés. Par contre, si vous maintenez peu d'application (et/ou qu'elles
sont très différentes les unes des autres), écrire une moulinette
de post-traitement adaptée à tous les cas va probablement représenter
un investissement assez lourd ; et vous voudrez certainement vérifier
son travail pendant un bon moment avant de la laisser aveuglément
générer du YAML qui partira directement en production.

Je suis un grand partisan de l'automatisation, mais avant d'automatiser
quelque chose, il faut être capable de le faire ...


## ... À la main

Pour bien comprendre comment les outils évoqués fonctionnent,
le meilleur moyen, c'est encore de faire leur travail à la main.

Entendons-nous bien : je ne conseille pas particulièrement de faire
ce boulot sur toutes vos applications (surtout si vous en avez
beaucoup!), mais je voudrais présenter "ma" méthodologie pour convertir
une application Compose en ressources Kubernetes.

L'idée fondamentale est simple : chaque ligne du fichier Compose
doit être traduite dans le résultat sur Kubernetes. Si j'affichais
ou imprimais les deux côte à côte, depuis chaque ligne du fichier
Compose, je devrais être capable de tracer un flèche vers son
expression dans Kubernetes.

Cela me permet d'être sûr que je n'ai rien oublié.

Ensuite, il faut savoir comment exprimer chaque section, chaque
paramètre, chaque option du fichier Compose. Voyons un petit exemple
en action !

```yaml
# Fichier Compose                                                  | traduction
version: "3"                                                       |
  services:                                                        |
    php:                                                           | deployment/php
      image: jpetazzo/apptruc:v1.2.3                               | deployment/php
      external_links:                                              | service/db
      - 'mariadb_db_1:db'                                          | service/db
      working_dir: /var/www/                                       | ignoré
      volumes:                                                     | \
      - './apache2/sites-available/:/etc/apache2/sites-available/' |  \
      - '/var/logs/apptruc/:/var/log/apache2/'                     |   \
      - '/var/volumes/apptruc/wp-config.php:/var/www/wp-config.php'|    \ volumes
      - '/var/volumes/apptruc/uploads:/var/www/wp-content/uploads' |    /
      - '/var/volumes/apptruc/composer:/root/.composer'            |   /
      - '/var/volumes/apptruc/.htaccess:/var/www/.htaccess'        |  /
      - '/var/logs/apptruc/app.log:/var/www/logs/application.log'  | /
      ports:                                                       | service/php
      - 8082:80                                                    | service/php
      healthcheck:                                                 | \
        test: ["CMD", "curl", "-f", "http://localhost/healthz"]    |  \
        interval: 30s                                              |   liveness probe
        timeout: 5s                                                |  /
        retries: 2                                                 | /
      extra_hosts:                                                 | hostAliases
      - 'sso.apptruc.fr:10.10.22.34'                               | hostAliases
```

Ci-dessus, un vrai fichier Compose utilisé par
un de mes clients. J'ai remplacé les noms d'image et d'hôte pour
respecter la confidentialité de mon client, mais en dehors de ça
tout est authentique. Ce fichier Compose est utilisé pour faire
tourner en préproduction une application basée sur une *stack*
LAMP. Pour l'instant l'application tourne sur une seule machine,
mais la prochaine étape est de la "Kubernetiser" (et permettre
un *scaling* horizontal si nécessaire).

J'ai annoté le fichier Compose afin d'indiquer en face de chaque
ligne comment je l'ai traduite en ressources Kubernetes.
La semaine prochaine, je publierai la seconde partie de cette
article, dans laquelle je détaillerai point par point comment
j'ai établi la correspondance entre Compose et Kubernetes.

Tout ça a demandé beaucoup de travail ; travail spécifique
à cette application, de surcroît. Comment répéter ça
efficacement pour d'autres applications ? Dans le cas
de mon exemple, mon client a toute une brochette d'applications
similaires. Le but est alors de construire un modèle
d'application (par exemple, sous forme de [Helm](https://www.helm.sh/) Chart)
qu'on pourra réutiliser, ou au moins utiliser comme base,
pour plusieurs applications.

Si les applications sont différentes les unes des autres,
on n'y coupe pas : il faut les convertir une par une.

Je conseille alors de prendre le problème par les deux
bouts. C'est-à-dire qu'on peut convertir une application
à la main, puis se demander "qu'est-ce que je peux modifier
dans l'application originale (au format Compose) pour la
rendre plus facile à lancer sur Kubernetes?" Parfois, il
s'agit de changements très simples. Remplacer un nom
DNS par un nom court ; utiliser une variable d'environnement
pour changer le comportement du code ...
Si on normalise suffisamment nos applications, il est fort
possible qu'on puisse ensuite les traiter automatiquement
avec Kompose ou Docker Enterprise Edition ou un outil du même genre.


## Conclusions

Passer de Compose à Kubernetes nécessite de transformer le
fichier Compose en multiples ressources Kubernetes. Il existe
des outils (comme Kompose) permettant de le faire automatiquement,
mais ces outils ne sont pas la panacée (en tout cas, pas encore).

Même si on utilise un outil, il faut être capable de comprendre
ce qu'il produit. Il faut donc
être familier avec Kubernetes, ses concepts, et ses différents types
de ressources.

{% include ad_fr_long.markdown %}

*La semaine prochaine, je publierai la seconde partie de cette
article, qui entrera dans les détails techniques pour expliquer
comment on a adapté cette application LAMP pour la faire tourner
sur Kubernetes!*
