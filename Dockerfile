FROM debian:sid

RUN apt-get update -q
RUN apt-get install -yq build-essential make
RUN apt-get install -yq zlib1g-dev
RUN apt-get install -yq ruby ruby-dev
RUN apt-get install -yq python-pygments
RUN apt-get install -yq nodejs
RUN apt-get install -yq cmake
RUN gem install --no-rdoc --no-ri github-pages

COPY . /blog
WORKDIR /blog

VOLUME /blog/_site

EXPOSE 4000
CMD ["jekyll", "serve", "--host", "0.0.0.0", "--incremental", "--verbose"]
