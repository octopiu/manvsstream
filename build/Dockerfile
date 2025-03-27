FROM ubuntu:24.04 AS base

ARG DEBIAN_FRONTEND=noninteractive
RUN apt update && apt install -y wget make libreadline-dev
RUN wget https://www.lua.org/ftp/lua-5.1.5.tar.gz && mkdir /lua && tar -xC /lua -f lua-5.1.5.tar.gz lua-5.1.5/src --strip-components=2

FROM base AS linux-build
RUN apt install -y clang && apt clean
RUN cd /lua && make linux CC=clang
COPY ./src /src
RUN cd /src && clang -shared -O3 -fPIC -o mvslib.so mvslib.c -I/lua -L/lua -llua -mavx2

FROM scratch AS copy-so
COPY --from=linux-build /src/mvslib.so /

FROM base AS windows-build
RUN apt install -y mingw-w64 binutils && apt clean
RUN cd /lua && make mingw CC=x86_64-w64-mingw32-gcc
COPY ./src /src
RUN cd /src && x86_64-w64-mingw32-gcc -O3 -fPIC -shared -o mvslib.dll mvslib.c -I/lua -L/lua -llua51 -mavx2

FROM scratch AS copy-dll
COPY --from=windows-build /src/mvslib.dll /
