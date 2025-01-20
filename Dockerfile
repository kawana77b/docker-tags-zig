FROM alpine:3.20

RUN apk add --no-cache curl bash wget build-base musl-dev zip

RUN curl https://raw.githubusercontent.com/tristanisham/zvm/master/install.sh | bash

RUN echo "# ZVM" >> $HOME/.profile \
  && echo 'export ZVM_INSTALL="$HOME/.zvm/self"' >> $HOME/.profile \
  && echo 'export PATH="$PATH:$HOME/.zvm/bin"' >> $HOME/.profile \
  && echo 'export PATH="$PATH:$ZVM_INSTALL/"' >> $HOME/.profile \
  && source ~/.profile

ARG ZVM_CMD=/root/.zvm/self/zvm
ARG ZIG_VERSION=0.13.0

RUN ${ZVM_CMD} install ${ZIG_VERSION} --zls && ${ZVM_CMD} use ${ZIG_VERSION}

WORKDIR /app

CMD [ "/bin/ash" ]