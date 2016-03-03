FROM centos:centos5

RUN yum -y groupinstall "Development Tools"
RUN yum -y install sudo vim yum-utils openjade docbook-dtds docbook-style-dsssl docbook-style-xsl wget
RUN yum-builddep -y postgresql

ENV RPMFORGE rpmforge-release-0.5.3-1.el5.rf
RUN	rpm --import http://apt.sw.be/RPM-GPG-KEY.dag.txt &&\
	wget http://pkgs.repoforge.org/rpmforge-release/${RPMFORGE}.x86_64.rpm &&\
	rpm -i ${RPMFORGE}.x86_64.rpm &&\
	yum -y install ccache git

# Prepare a newer flex and bison. We'll rebuild from CentOS 6.
RUN yum -y install rpm-build yum-utils redhat-rpm-config java-1.6.0-openjdk-devel
# Prepare for user level RPM builds on prehistoric rpm
RUN mkdir -p ~/rpmbuild/{BUILD,RPMS,SOURCES,SPECS,SRPMS} && echo '%_topdir %(echo $HOME)/rpmbuild' > ~/.rpmmacros
# rebuild flex. Our ancient rpm and rpmbuild means we have to use some
# workarounds to build newer srpms.
ENV FLEXVER=flex-2.5.35-9
RUN	wget http://ftp.redhat.com/pub/redhat/linux/enterprise/6Server/en/os/SRPMS/${FLEXVER}.el6.src.rpm &&\
	rpm -i --nomd5 ${FLEXVER}.el6.src.rpm &&\
	rpmbuild -ba ~/rpmbuild/SPECS/flex.spec
ENV BISONVER=bison-2.4.1-5
RUN	wget http://ftp.redhat.com/pub/redhat/linux/enterprise/6Server/en/os/SRPMS/${BISONVER}.el6.src.rpm &&\
	rpm -i --nomd5 ${BISONVER}.el6.src.rpm &&\
	rpmbuild -ba ~/rpmbuild/SPECS/bison.spec
# install 'em
RUN yum -y --nogpgcheck localinstall ~/rpmbuild/RPMS/x86_64/flex* ~/rpmbuild/RPMS/x86_64/bison*

# Create a normal user for the rest of the work
#
# Set this to your uid in your normal account to avoid issues with
# permissions when sharing a build dir. Or use VPATH builds.
ENV userid=1000

RUN useradd -u ${userid} -m pgtaptest
# Permit sudo. Note a password is required, but none is set by default.
# You can set a password later in the file if you want sudo.
RUN usermod -G wheel -a pgtaptest

RUN	mkdir -p /pg/build /pg/ccache /pg/source &&\
	chown pgtaptest /pg/build /pg/ccache /pg/source &&\
	chmod ug=rwsX,o=rX /pg/build /pg/ccache /pg/source

ENV CCACHE_DIR /pg/ccache

# Do future work as the user we created
ENV HOME=/home/pgtaptest/
USER pgtaptest
WORKDIR ${HOME}

RUN wget -q --no-check-certificate -O - http://cpanmin.us | perl - App::cpanminus

RUN ${HOME}/perl5/bin/cpanm -l ${HOME}/perl5 local::lib
RUN perl -I ~/perl5/lib/perl5/ -Mlocal::lib >> ${HOME}/.bash_profile

RUN eval $(perl -I ~/perl5/lib/perl5/ -Mlocal::lib) && ${HOME}/perl5/bin/cpanm -l ${HOME}/perl5 IPC::Run


# To keep the dockerfile self-contained generate the script from echo
#
RUN mkdir -p ${HOME}/bin && echo -e "#!/bin/bash\nif [ -e /pg/source/src/port/pg_config_paths.h ]\nthen\necho \"ERROR: datadir must be cleaned - src/port/pg_config_paths.h exists\"\nelse\n/pg/source/configure --enable-cassert --enable-debug --enable-tap-tests && make clean && make -j4 && make -C src/test/recovery check\nfi" >> ${HOME}/bin/recovery-check && chmod a+x ${HOME}/bin/recovery-check

# Sudo management. It's here not earlier so you don't have to rebuild the whole
# image and flush the cache if you change it.
USER root
RUN echo -e 'pgtaptest:IuxoPoh1ki' | chpasswd
RUN echo '%wheel  ALL=(ALL) ALL' >> /etc/sudoers
# If you want passwordless sudo, enable this:
#RUN echo '%wheel  ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers
USER pgtaptest

# Build this image with:
#    docker build -t pgtaptest .
#
# Run with:
#    docker run -i -t -v /path/to/my/postgres/tree:/pg/source -v /path/to/builddir:/pg/build -v /path/to/ccache:/pg/ccache pgtaptest
#
# Use an alias or script to make it more convenient. If you want /pgbuild to be
# transient just don't set a -v for it, so it's cleared every run.
#
# Clean up exited instances with
#    docker rm $(docker ps -a -q)
#
# To run tests
#
#   recovery-check

WORKDIR /pg/build
ENTRYPOINT ["/bin/bash", "--login"]
