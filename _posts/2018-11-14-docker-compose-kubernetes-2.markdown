---
layout: post
title: "De Docker à Kubernetes en passant par Compose (2/2)"
---

Cette article est la suite du [précédent](/2018/11/07/docker-compose-kubernetes-1/).
Aujourd'hui, on va entrer dans les détails pour voir
comment adapter une application décrite par un fichier
Compose afin de la faire tourner sur Kubernetes.

*If you still can't read French and wonder what this
post is about: it's an in-depth description of a technique
that one can use to transform an app described by a Compose file
into a set of Kubernetes resources.*

J'aime bien écrire des articles pour mon blog, mais j'aime
encore mieux former des gens brillants (par exemple, vous,
chers lecteurs) à tous ces sujets : les conteneurs,
Kubernetes, Docker ... Du coup, petite annonce :

{% include ad_fr_short.markdown %}


## Résumé des épisodes précédents

On veut donc "Kubernetiser" le Compose file ci-dessous :


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

Pour rappel, c'est un vrai fichier Compose utilisé par
un de mes clients. J'ai uniquement changé les noms d'image
et d'hôte par souci de confidentialité, mais en dehors de ça,
cest un vrai fichier représentatif de ce qu'on trouve dans
la nature.

J'ai annoté le fichier pour montrer (dans la partie droite)
à quel concept ou ressource Kubernetes correspond chaque ligne.

Maintenant, voyons ça un peu plus en détail !


## Où sont mes conteneurs ?

Tout d'abord. pour chaque service (au sens de Compose),
j'ai créé un *Deployment* dans Kubernetes. Par simplicité, je nomme
ce *Deployment* comme le service Compose (ici, `php`).

Pour générer le YAML de mon *Deployment*,
j'utilise la commande suivante:

```bash
kubectl create deployment php \
        --image jpetazzo/apptruc:v1.2.3 \
        --dry-run -o yaml
```

*Normalement,* cette commande génère la description d'une
ressource (ici, un `deployment`) puis crée cette ressource
sur le cluster. Mais comme on utilise l'option `--dry-run`,
on se contente de générer la description, sans créer la ressource.
On assure l'affichage de cette description au format YAML avec
(vous l'aurez sûrement deviné) le `-o yaml`.

Juste là, tout va bien.


## Connexions sortantes

Ensuite, je vois une section `external_links`, qui va faire correspondre
le conteneur `mariadb_db_1` au nom `db`. Je vais donc créer un service Kubernetes
qui va s'appeler `db`. Plusieurs options s'offrent à moi.

Dans le cas présent, il se trouve que la base de données `mariadb_db_1`
est exposée sur le port 3306 sur une machine appelée `db.apptruc.fr`.
La solution la plus simple est alors de créer un service de type `ExternalName`.
Concrètement, cela va se contenter d'ajouter un enregistrement DNS de
type `CNAME` dans le DNS de Kubernetes (kube-dns ou CoreDNS, selon la
version de Kubernetes qu'on utilise). Du coup, quand mon application
va résoudre le nom `db`, le DNS de Kubernetes va lui dire "le nom
`db` correspond au `CNAME` `db.apptruc.fr` ; au passage, l'adresse
IP correspondante est `10.20.30.40`."

Si mon serveur MariaDB n'est pas dans le DNS (et que j'ai juste son
adresse IP), mauvaise nouvelle : à l'heure où j'écris ces lignes
(Kubernetes 1.12), un `ExternalName` ne peut pas pointer directement
vers une adresse IP. Si je ne peux pas (ou ne veux pas) créer une
entrée DNS pour mon serveur MariaDB, je peux utiliser [nip.io](http://nip.io/).
Grâce à nip.io, je peux obtenir un nom DNS pour n'importe quelle
adresse IP. Il suffit d'ajouter `.nip.io` derrière l'adresse IP !
Autrement dit, si mon serveur MariaDB a l'adresse `10.20.30.40`,
je peux créer un `ExternalName` pointant vers `10.20.30.40.nip.io`
et le tour est joué.

(Notons au passage que même si nip.io est très pratique, l'utiliser
crée un dépendance à un service externe. Cela implique aussi que
notre cluster a accès à Internet. Ce n'est pas une contrainte très
lourde dans la majorité des cas, sauf pour les gens qui font tourner
des clusters totalement isolés de l'extérieur...)

Tout ça fonctionne uniquement si mon serveur MariaDB est exposé sur
le port par défaut (3306). Comment faire si mon serveur est exposé
sur un autre port ?

**Option 1 : un [ambassadeur](https://docs.docker.com/v17.09/engine/admin/ambassador_pattern_linking/).**
Dans le cas présent, je pourrais
utiliser [hamba](https://github.com/jpetazzo/hamba). Cela me ferait ajouter un *Deployment*.
L'ambassadeur va écouter sur le port 3306, et relayer chaque
connexion vers l'adresse et port qu'on voudra. On pourrait
aussi utiliser un proxy MySQL comme ambassadeur.

**Option 2 : un service `ClusterIP` et un *backend* statique.**
Normalement, dans Kubernetes, un service obtient la liste
des *backends* (ou *endpoints*) grâce à un sélecteur. Par exemple, le sélecteur
peut indiquer "ce service correspond à tous les pods ayant
le label `app=toto`". À chaque fois qu'un pod ayant ce label
apparaît ou disparaît, il est ajouté ou enlevé de la liste
des *backends* pour le service. Cela revient à une reconfiguration
dynamique de *load balancer*. Mais on peut aussi créer un
service sans sélecteur, puis gérer les *backends* soi-même.

Comme faire en pratique ? Tout simplement en chargeant un
fichier YAML similaire à l'exemple ci-dessous via `kubectl create`:

```yaml
---
apiVersion: v1
kind: Service
metadata:
  name: db
spec:
  ports:
  - name: "3306"
    port: 3306
    protocol: TCP
    targetPort: 3306
  type: ClusterIP
---
apiVersion: v1
kind: Endpoints
metadata:
  name: db
subsets:
- addresses:
  - ip: 10.20.30.40     # Changer ça
  ports:
  - name: "3306"
    port: 12345         # Et ça
    protocol: TCP
```

(Remplacez `10.20.30.40` et `12345` par l'adresse IP et le
port auquel le service doit correspondre, et le tour est joué!)


## Évitez de déployer trop gras, trop salé ou trop sucré

La ligne suivante du fichier Compose est `working_dir`.
Dans l'absolu, je pourrais répercuter cette directive dans
le fichier YAML du déploiement `php`. Mais dans ce cas
précis, je me suis posé la question : est-ce que cette
directive est nécessaire ? Il s'avère qu'elle n'était pas
utile, donc on s'en est débarrassé.

Il y a une petite leçon importante ici : d'un côté,
c'est important de s'assurer qu'on a bien transcrit toutes
les informations présentes dans le fichier Compose. De
l'autre, recopier aveuglément les informations peut conduire
à une accumulation de petites choses inutiles (voire
contre-productives), dont on ne sait plus trop à quoi
elles servent.

C'est particulièrement vrai dans des (longs) fichiers
de configuration, et tout particulièrement des fichiers
générés. Ces fichiers ont tendance à être longs (un programme
sera toujours moins paresseux qu'un humain et ne rechignera
jamais à ajouter des lignes!) et pas toujours commentés.

Il m'est arrivé bien trop souvent de faire le ménage
dans un configuration de plusieurs centaines de lignes,
la réduisant à moins de dix lignes utiles. Tout le reste,
c'était des valeurs par défaut, ou bien sans incidence
sur l'application. Le résultat, c'est une configuration
beaucoup plus lisible, facile à comprendre, et facile
à porter ou traduire lorsqu'on change de système ou
tout simplement qu'on fait une montée en version.


## Monter les volumes

Puis, on a une ribambelle de volumes. On a pu les classer en
trois catégories :

- configuration,
- logs,
- *assets* (images et autres).

La configuration et les logs sont répartis sur plusieurs
répertoires. On aurait pu créer plusieurs volumes de
configuration et plusieurs volumes de logs, mais on
a choisi une méthode légèrement différente.

Pour commencer, on rassemble tous les fichiers de
configuration identifiés dans un répertoire `config`,
puis on transforme ce répertoire en une *ConfigMap*
Kubernetes avec la commande suivante :

```bash
kubectl create configmap config --from-file=config \
        --dry-run -o yaml > configmap-config.yaml
```

Cette *ConfigMap* sera montée sous forme de volume
(par exemple dans `/config`), ce qui va
rematérialiser le contenu du répertoire `config` dans chaque
container de l'application.

Puis, on va modifier la commande de lancement de l'application,
afin de créer des liens symboliques vers tous ces fichiers.
Ainsi, à l'emplacement de chaque fichier de configuration
attendu par l'application, on aura un lien symbolique pointant
vers le fichier de configuration contenu dans `/config`,
et ce répertoire correspond à une *ConfigMap* Kubernetes.

On procède de manière similaire pour les logs. Là encore,
chaque fichier ou répertoire de log de l'application est
remplacé par un lien symbolique vers `/logs`, et `/logs`
est un volume.

Voici un extrait du fichier YAML du *Deployment* `php`:

```yaml
command:
- "sh"
- "-c"
- |
  set -e
  ln -sf /config/wp-config.php /var/www/wp-config.php
  ln -sf /config/.htaccess /var/www/.htaccess
  mkdir /etc/apache2/sites-include
  ln -sf /config/url-redirections /etc/apache2/sites-include/url-redirections
  ln -sf /config/000-default.conf /etc/apache2/sites-available/000-default.conf
  [ -d /logs/apache2 ] || mv /var/log/apache2 /logs/apache2
  ln -sf /logs/apache2 /var/log/apache2
  ln -sf /logs/application.log /var/www/logs/application.log
  exec sudo apachectl -DFOREGROUND
```

Il y a pas mal de choses à dire sur cette section `command` !

- Chaque volume déclaré dans le fichier Compose se trouve traduit
  ici (par une commande `ln -sf` adéquate).
- Puisqu'on a plusieurs commandes à exécuter, on le fait
  via `sh -c "une_commande && une_autre_commande && encore_une"`.
- Plutôt que d'enchaîner toutes les commandes avec `&&`, on
  place un `set -e` au début. Cela évite d'oublier un `&&`
  malencontreusement (ce qui aurait pour conséquence de
  permettre le lancement de l'application même si un lien
  n'a pas pu être créé correctement).
- Afin de rendre ça lisible, on utilise une chaîne YAML
  multi-lignes comme argument de `sh -c`. Imaginez ce
  que ça donnerait si le script était condensé sur une
  seule ligne avec des `;` pour séparer les commandes !
- À la fin, quand on lance le point d'entrée du conteneur,
  on le fait avec `exec`, afin que le point d'entrée soit
  bien le PID 1 dans le conteneur. Si on faisait directement
  `sudo apachectl` (sans `exec`), alors le PID 1 serait `sh`
  et `sudo apachectl` serait un sous-processus.
- Pour savoir quoi lancer (d'où vient ce `sudo apachectl`?)
  on a simplement fait un `docker inspect` sur l'image.

Enfin, pour les *assets*, la meilleure méthode serait
(idéalement!) de remplacer ce répertoire partagé par un
*object store*. Mais cela implique des modifications assez
lourdes sur l'application, donc en attendant, on peut
utiliser (par exemple) un partage NFS.

Les volumes et les *ConfigMaps* sont des concepts complexes.
Si vous voulez en savoir plus à ce sujet, vous pouvez
consulter :

- [la documentation Kubernetes sur les volumes](https://kubernetes.io/docs/concepts/storage/volumes/),
- [notre support de formation sur les volumes](https://container.training/kube-selfpaced.yml.html#toc-volumes),
- [la documentation Kubernetes sur les ConfigMaps](https://kubernetes.io/docs/tasks/configure-pod-container/configure-pod-configmap/),
- [notre support de formation sur la configuration des applicatifs avec Kubernetes](https://container.training/kube-selfpaced.yml.html#toc-managing-configuration).


## Connexions entrantes

On poursuit avec la section `ports`. Cette application
se trouve derrière un *load balancer* HAProxy, configuré
pour envoyer les requêtes sur le port 8082 de l'hôte Docker
où elle se trouve. On va garder le même schéma, mais on
va utiliser un service de type `NodePort` et configurer
HAProxy pour envoyer les requêtes vers tous les nœuds
de notre cluster Kubernetes, sur le port alloué.

Si on avait voulu aller plus loin, on aurait pu créer
un *Ingress*. Cela aurait permis de remplacer le *load
balancer* HAProxy par un mécanisme mieux intégré à Kubernetes,
comme [Traefik](https://traefik.io/) par exemple.

Dans ce cas précis, mon client souhaitait garder ses
*load balancers* existants afin de migrer plus progressivement.
C'est une démarche très saine, qui limite la quantité
de nouveaux outils à prendre en main pour les équipes
opérationnelles. Du coup, on utilise un `NodePort`
pour coller au plus près à l'existant.

Pour en savoir plus sur les *Ingress*, vous pouvez consulter
[la documentation Kubernetes](https://kubernetes.io/docs/concepts/services-networking/ingress/)
ou notre [support de formation](https://container.training/kube-selfpaced.yml.html#toc-exposing-http-services-with-ingress-resources).


## Sondes

La section `healthcheck` est remplacée par une *liveness
probe* dans le *Deployment*. Je ne vais pas entrer dans
les détails (cet article est déjà assez long comme ça),
et simplement mentionner que cela permet de détecter si
le conteneur a un problème, et le redémarrer automatiquement
le cas échéant. Pour en savoir plus sur ces sondes, et sur
la différence entre les sondes de *liveness* et de *readiness*,
je vous invite à consulter la [documentation](
https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-probes/
) ou bien encore une fois notre [support de formation](
https://container.training/kube-selfpaced.yml.html#toc-healthchecks
).


## Connexions sortantes (bis)

Enfin, la section `extra_hosts` permet d'injecter
des entrées DNS supplémentaires. Dans le cas présent,
le nom `sso.apptruc.fr` correspond à une adresse IP
publique, et (dans le cas précis du réseau de ce client)
utiliser cette adresse IP publique fait passer le trafic par
le firewall. La section `extra_hosts` permet de surcharger
ce nom DNS afin de lui faire correspondre l'adresse IP
privée du service, et y accéder directement, sans passer
par le firewall. (C'est une topologie spécifique à ce client,
mais qu'on retrouve dans d'autres circonstances ; par exemple,
dans une infrastructure *cloud*, lorsqu'une machine interne
accède à un service interne, mais via son adresse IP externe.)

Cette section `extra_hosts` peut se traduire via une
section `hostAliases` dans le *Deployment*.
(C'est particulièrement bien expliqué dans la [documentation
Kubernetes](
https://kubernetes.io/docs/concepts/services-networking/add-entries-to-pod-etc-hosts-with-host-aliases/
).)

Cela dit, si on a plusieurs *Deployment* qui accèdent à
un service de cette façon, on peut aussi souhaiter mettre
en place quelque chose qui surcharge le nom DNS de ce service
automatiquement pour tous les services.

Pour des noms courts (comme `db` ou `api`) on peut créer
un service Kubernetes (comme expliqué plus haut pour
`db`), mais pour un nom contenant des points (comme
`sso.apptruc.fr`) cela n'est pas possible, car on
ne peut pas avoir de point dans le nom d'une ressource
Kubernetes. On peut, en revanche, configurer le
DNS de Kubernetes pour "détourner" les requêtes pour
`sso.apptruc.fr` afin de renvoyer une adresse IP de
notre choix. Là aussi, il s'agit d'une opération non
triviale. Si vous voulez en savoir plus à ce sujet,
vous pouvez consulter [cet excellent article en anglais](
https://coredns.io/2017/05/08/custom-dns-entries-for-kubernetes/).

Une autre solution est de changer le code afin
d'accéder à `sso` (au lieu de `sso.apptruc.fr`) puis
créer un service `sso`.


## Conclusions

Ouf ! On a converti notre application. Et comme
vous pouvez le constater sur cet exemple en conditions
réelles, les outils automatiques ont leurs limites.
Un outil comme Kompose, aussi sophistiqué soit-il,
n'aurait pas pu créer automatiquement un partage NFS pour nous.
Les outils actuels ne sont pas capables de deviner
quels fichiers sont des fichiers de configuration
(et peuvent être encapsulés dans une *ConfigMap*) et
quels fichiers sont des logs (et peuvent être placés
dans un volume *EmptyDir* partagé avec un conteneur 
*sidekick* les relayant vers notre plateforme de
logging). Peut-être que ça viendra, mais on n'y est pas
encore.

Comme évoqué dans [l'article précédent](/2018/11/07/docker-compose-kubernetes-1/), il
est plus efficace de prendre le problème par les deux
bouts : d'un côté, utiliser un outil comme Kompose
pour automatiser le boulot ; de l'autre, analyser
le résultat, comprendre ce qui n'est pas traduit
correctement, le corriger à la main, mais à terme,
modifier le fichier Compose en amont de manière
à ce que Kompose puisse mieux faire son travail lors
de la prochaine passe.

Dans tous les cas, on n'y coupe pas : il faut
se familiariser avec Kubernetes !

{% include ad_fr_long.markdown %}
