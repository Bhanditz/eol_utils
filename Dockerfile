FROM ruby:2.1-onbuild
MAINTAINER Jeremy Rice <jrice@eol.org>
ENV LAST_FULL_REBUILD 2016-08-24
RUN bundle install
CMD /bin/bash
