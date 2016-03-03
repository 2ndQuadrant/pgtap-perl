Dockerfile for testing Postgres TAP tests with Perl 5.8.8
====

PostgreSQL's Perl-based TAP tests (for binaries, crash recovery, etc)
are required to run under Perl versions as old as 5.8.8, which is of
Debian Etch / CentOS 5 vintage. Perl does not offer good tools for
backward compatibility testing on a modern Perl.

This Dockerfile produces a canned Perl 5.8.8 environment based on CentOS 5 on
any host with Docker. It has ccache installed and enabled, git installed,
IPC::Run installed, all the mess required to make CPAN work sensibly done, etc.
So you can test your patches on oldperl.

Once you build the container once you can quickly re-use it to run test builds.
You can map a postgres source tree, working tree and ccache directory from the
host to make them persistent.

Understand that this container runs code fetched directly off the 'net as root,
albeit root within a container, during setup. It avoids running all the
perl/cpan stuff as root though, switching to a normal user as soon as it's
installed the required RPMs from centos repos and rpmforge, so it's not just
curl'ing random scripts into bash/perl as root.

To build the container:

	mkdir pgtaptest
	cp /path/to/Dockerfile pgtaptest
	cd pgtaptest
	docker build -t pgtaptest .

To run a shell in the container environment:

	alias pgtaptest="docker run -i -t \
	  -v /path/to/my/postgres/tree:/pg/source \
	  -v /path/to/builddir:/pg/build \
	  -v /path/to/ccache:/pg/ccache \
	  pgtaptest'

	pgtaptest

Once in the working environment's shell, `/pg/source` is the mapped source
tree, `/pg/build` is the mapped build tree (or an empty dir, if you didn't map
it), and `/pg/ccache` is the mapped ccache or - again - an empty tree if you
didn't map it.

Unmapped volumes get discarded when the container instance exits.

There's a preconfigured script, `recovery-check`, that configures and makes
postgres and runs the recovery tests. To run it directly from the host,
assuming you created the alias above, just:

	pgtaptest recovery-check

Happy Perl 5.8'ing!
