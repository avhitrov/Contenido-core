##############################################################################
# $HeadURL$
# $Id$
###############################################################################

# installation settings
include ../../config.mk

# local defines
SOURCES =	${ROOT_DIR}/src
CORE_SRC =	${SOURCES}/core
PLUG_SRC =	${SOURCES}/plugins
PROJ_SRC =	${SOURCES}/projects

CORE_USR =	${ROOT_DIR}/usr/core
PLUG_USR =	${ROOT_DIR}/usr/plugins
PROJ_USR =	${ROOT_DIR}/usr/projects
PROJ_TMP =	${ROOT_DIR}/tmp/projects
PROJ_VAR =	${ROOT_DIR}/var/projects

PORTSDIR =	${CORE_SRC}/ports
LOCAL =		${ROOT_DIR}/usr/local
PORTSWRK =	${ROOT_DIR}/var/ports

CORE_VERSION =	${shell svnversion ${CORE_SRC}}

PAGER ?=	${shell which less || which more}
RSYNC_COMMAND =	${shell which rsync}

HOSTNAME =	${shell hostname}

PROJECT_LC =	${shell echo "${PROJECT}" | tr '[:upper:]' '[:lower:]'}

# core settings
include ${CORE_SRC}/config.mk

# perl settings 
include ${CORE_SRC}/ports/etc/perl.mk

# project settings
ifdef PROJECT
ifneq (${shell test -f ${PROJ_SRC}/${PROJECT}/config.mk && echo 1},1)
${error ERROR: no source ${PROJECT}/config.mk found, are you checked out project '${PROJECT}'?}
endif
-include /usr/local/etc/contenido.mk
RSYNC_SERVERS ?=	${addsuffix ::${PROJECT_LC}, ${FRONTENDS}}
include ${PROJ_SRC}/${PROJECT}/config.mk
include ${CORE_SRC}/project-default.mk

ifeq (${shell test -f ${PROJ_SRC}/${PROJECT}/GNUmakefile && echo 1},1)
include ${PROJ_SRC}/${PROJECT}/GNUmakefile
$(warning Use of GNUmakefile in project dir is deprecated, rename it to GNUmakefile.in)
endif
-include ${PROJ_SRC}/${PROJECT}/GNUmakefile.in

PROJECT_VERSION =	${shell svnversion ${PROJ_SRC}/${PROJECT}}
endif

.PHONY:											\
			local_clean			realclean			\
			local_build			build				\
			local_install			install				\
			local_preview			preview				\
											\
			core_status			cst				\
			core_update			cup				\
			core_commit			cci				\
			core_checkout			cco				\
			core_push			cpush				\
			core_pull			cpull				\
			core_branch			cbranch				\
			core_merge			cmerge				\
			core_install			cin				\
			core_info			cinfo				\
			core_rsync			crs				\
											\
			project_assets			assets				\
			project_assets_dev		assdev				\
			project_status			pst				\
			project_update			pup				\
			project_commit			pci				\
			project_checkout		pco				\
			project_push			ppush		push		\
			project_pull			ppull		pull		\
			project_branch			pbranch		branch		\
			project_merge			pmerge		merge		\
			project_install			pin				\
			project_conf			conf				\
			project_rsync			prs				\
			project_assets_rsync		ars				\
			project_start			start				\
			project_stop			stop				\
			project_create			create				\
			project_import			import				\
			project_info			pinfo				\
			project_reload			reload				\
			project_fullreload		full				\
			project_rewind			rewind		nano		\
			project_refresh			refresh				\
			project_deinstall		pdi				\
			project_user			user				\
			project_switch			switch		swi		\
			project_backup			backup				\
											\
			plugin_create			plc				\
			plugins_commit			plci				\
			plugins_checkout		plco				\
			plugins_push			plpush				\
			plugins_pull			plpull				\
			plugins_branch			plbranch			\
			plugins_merge			plmerge				\
			plugins_install			plin				\
			plugins_status			plst				\
			plugins_update			plup				\
			plugins_deinstall		pldi				\
											\
			pgsql_init							\
			pgsql_start							\
			pgsql_stop							\
			pgsql_psql			psql				\
			pgsql_dump			dump				\
			pgsql_dumpz			dumpz				\
											\
			apache_access_log		alog				\
			apache_pager_access_log		palog				\
			apache_error_log		elog				\
			apache_pager_error_log		pelog				\
			apache_start							\
			apache_stop							\
											\
			check_conf_installed						\
			check_core_installed						\
			check_owner							\
			check_project							\
			check_project_installed						\
			check_user							\

#################
# local_* targets
#################

# build all required ports (core & project)
build: local_build ;
local_build: check_user
	@for P in ${CORE_REQUIRED} ${PROJECT_REQUIRED}; do				\
		${MAKE} -s port_build PORT=$${P}					\
		|| exit 1;								\
	done;
	@echo $@ done

# install all required ports (core & project)
install: local_install ;
local_install: check_user
	@for P in ${CORE_REQUIRED} ${PROJECT_REQUIRED}; do				\
		${MAKE} -s port_install PORT=$${P}					\
		|| exit 1;								\
	done;
ifeq (${DB_TYPE},SINGLE)
	@${MAKE} -s pgsql_init
endif
	@echo $@ done

# preview of install all required ports (core & project)
preview: local_preview ;
	@for P in ${CORE_REQUIRED} ${PROJECT_REQUIRED}; do				\
		${MAKE} -s port_install PORT=$${P} DRY_RUN=yes				\
		|| exit 1;								\
	done;



################
# core_* targets
################

# check core sources via repository
cst: core_status ;
core_status: check_user
ifeq (${VCS_TYPE},git)
	@echo ${PROJ_SRC}/${PROJECT}
	@cd ${CORE_SRC} && git status
else
	@svn st -u ${CORE_SRC}
endif
	@echo $@ done

# update core sources from repository
cup: core_update ;
core_update: check_user
ifeq (${VCS_TYPE},git)
	@cd ${CORE_SRC}									\
	&& echo ">>>> core git pull"							\
	&& git pull;
else
	@if [ -n "${REV}" ]; then							\
		svn up -r ${REV} ${CORE_SRC};						\
	else										\
		svn up ${CORE_SRC};							\
	fi;
endif
	@echo $@ done

# commit core changes to repository
cci: core_commit ;
core_commit: check_user
ifeq (${VCS_TYPE},git)
	@cd ${CORE_SRC} && git commit -a
else
	@svn ci ${CORE_SRC}
endif
	@echo $@ done

# pretty formatted core info
cinfo: core_info ;
core_info:
	@REPOS=`svn info ${CORE_SRC} | grep -E '^URL' | sed -E 's/URL: //'`;		\
	RL=$$(($${#REPOS}+2));								\
	DEVEL=`perl -e 'print "".(lc "${DEVELOPMENT}" eq "yes" ? "YES" : "NO");'`;	\
	DEBUG=`perl -e 'print "".(lc "${DEBUG}" eq "yes" ? "YES" : "NO");'`;		\
	printf "%-$${RL}s %-12s %-7s %-7s %-6s\n" REPOSITORY REVISION DEVEL DEBUG PORT;	\
	printf "%-$${RL}s %-12s %-7s %-7s %-6s\n" $${REPOS} ${CORE_VERSION} $${DEVEL}	\
		$${DEBUG} ${HTTPD_PORT}
	@echo $@ done


# core git checkout and branch switcher
cco: core_checkout ;
core_checkout:
	@cd ${PROJ_SRC}/${PROJECT}							\
	&& echo ">>>> git checkout ${BRANCH}"						\
	&& git checkout ${BRANCH};
	@echo $@ done

# core git branch workaround.
# Uses NAME as branch name for creation, FROM for branch source and DELETE=1 for branch delete
cbranch: core_branch ;
core_branch:
	@if [ -n "${NAME}" -a -n "${FROM}" ]; then					\
		cd ${CORE_SRC}								\
		&& echo ">>>> git checkout -b ${NAME} ${FROM}"				\
		&& git checkout -b ${NAME} ${FROM};					\
	elif [ -n "${NAME}" -a -n "${DELETE}" ]; then					\
		cd ${CORE_SRC}								\
		&& echo ">>>> git branch -d ${NAME}"					\
		&& git branch -d ${NAME};						\
	elif [ -n "${NAME}" ]; then							\
		cd ${CORE_SRC}								\
		&& echo ">>>> git checkout -b ${NAME}"					\
		&& git checkout -b ${NAME};						\
	else										\
		cd ${CORE_SRC}								\
		&& git branch -v;							\
	fi;
	@echo $@ done

# core git merge
cmerge: core_merge ;
core_merge:
	@if [ -n "${BRANCH}" ]; then							\
		cd ${CORE_SRC}								\
		&& echo ">>>> git merge --no-ff ${BRANCH}"				\
		&& git merge --no-ff ${BRANCH};						\
	else										\
		echo "Don't know what branch merge to current. Usage: make merge BRANCH=branch-to-merge-with";		\
	fi;
	@echo $@ done

# core git push
cush: core_push ;
cpush: core_push ;
core_push:
	@cd ${CORE_SRC}									\
	&& echo ">>>> git push"								\
	&& git push;
	@echo $@ done

# core git pull
cull: core_pull ;
cpull: core_pull ;
core_pull:
	cd ${CORE_SRC}									\
	&& echo ">>>> git pull"								\
	&& git pull;
	@echo $@ done

# install core into work directory
cin: core_install ;
ifeq (${DB_TYPE},SINGLE)
core_install: check_user pgsql_init
else
core_install: check_user
endif
	@if [ -d ${CORE_USR} ]; then							\
		chmod -R u+w ${CORE_USR}						\
		&& rm -Rf    ${CORE_USR};						\
	fi;

	@mkdir ${CORE_USR}								\
	&& cp -Rp ${CORE_SRC}/comps ${CORE_SRC}/lib ${CORE_SRC}/services ${CORE_USR}/	\
	&& find ${CORE_USR}/ -depth -type d -name .svn      -exec rm -Rf {} \;		\
	&& find ${CORE_USR}/ -depth -type f -name '*.proto' -exec rm  -f {} \;

	@for PROJ in `ls -1A ${PROJ_USR}/`; do						\
		ln -s ${PROJ_USR}/$${PROJ}/lib/$${PROJ} ${CORE_USR}/lib/$${PROJ};	\
	done;

	@chmod -R a-w ${CORE_USR}

ifeq (${DB_TYPE},SINGLE)
	@rm   -f ${LOCAL}/pgsql/data/pg_hba.conf					\
	&& rm -f ${LOCAL}/pgsql/data/pg_ident.conf					\
	&& cp ${CORE_SRC}/conf/pgsql/pg_hba.conf     ${LOCAL}/pgsql/data/		\
	&& touch ${LOCAL}/pgsql/data/pg_ident.conf

	@${call rewrite,${CORE_SRC}/conf/pgsql/postgresql.conf.proto,			\
			${LOCAL}/pgsql/data/postgresql.conf}
endif

	@echo $@ done


###################
# project_* targets
###################

# check project sources via repository
pst: project_status ;
project_status:: check_project
ifeq (${VCS_TYPE},git)
	@cd ${PROJ_SRC}/${PROJECT} && git status
else
	@svn st -u ${PROJ_SRC}/${PROJECT}
endif
	@echo $@ done

# pretty formatted project info (svn only)
pinfo: project_info ;
project_info:: check_project
	@REPOS=`svn info ${PROJ_SRC}/${PROJECT} | grep -E '^URL' | sed -E 's/URL: //'`;	\
	PL=$$(($${#PROJECT}+2)); [ $${PL} -lt 9 ] && PL=9; RL=$$(($${#REPOS}+2));	\
	printf "%-$${PL}s %-$${RL}s %-10s %s\n" PROJECT REPOSITORY REVISION PLUGINS;	\
	printf "%-$${PL}s %-$${RL}s %-10s ${PLUGINS}\n" ${PROJECT} $${REPOS} ${PROJECT_VERSION}
	@echo $@ done

# update project sources from repository
pup: project_update ;
project_update:: check_project
ifeq (${VCS_TYPE},git)
	@if [ -d ${PROJ_USR}/${PROJECT} ]; then						\
		cd ${PROJ_SRC}/${PROJECT}						\
		&& echo ">>>> git pull"							\
		&& git pull;								\
	fi;
else
	@if [ -n "${REV}" ]; then							\
		svn up -r ${REV} ${PROJ_SRC}/${PROJECT};				\
	else										\
		svn up ${PROJ_SRC}/${PROJECT};						\
	fi;
endif
	@echo $@ done

# commit project changes to repository
pci: project_commit ;
project_commit:: check_project
ifeq (${VCS_TYPE},git)
	@cd ${PROJ_SRC}/${PROJECT} && git commit -a
else
	@svn ci ${PROJ_SRC}/${PROJECT}
endif
	@echo $@ done

# project git checkout and branch switcher
pco: project_checkout ;
project_checkout:: check_project
	@if [ -d ${PROJ_USR}/${PROJECT} ]; then						\
		cd ${PROJ_SRC}/${PROJECT}						\
		&& echo ">>>> git checkout ${BRANCH}"					\
		&& git checkout ${BRANCH};						\
	fi;
	@echo $@ done

# project git branch workaround. 
# Uses NAME as branch name for creation, FROM for branch source and DELETE=1 for branch delete
branch: project_branch ;
pbranch: project_branch ;
project_branch:: check_project
	@if [ -n "${NAME}" -a -n "${FROM}" ]; then					\
		cd ${PROJ_SRC}/${PROJECT}						\
		&& echo ">>>> git checkout -b ${NAME} ${FROM}"				\
		&& git checkout -b ${NAME} ${FROM};					\
	elif [ -n "${NAME}" -a -n "${DELETE}" ]; then					\
		cd ${PROJ_SRC}/${PROJECT}						\
		&& echo ">>>> git branch -d ${NAME}"					\
		&& git branch -d ${NAME};						\
	elif [ -n "${NAME}" ]; then							\
		cd ${PROJ_SRC}/${PROJECT}						\
		&& echo ">>>> git checkout -b ${NAME}"					\
		&& git checkout -b ${NAME};						\
	else										\
		cd ${PROJ_SRC}/${PROJECT}						\
		&& git branch -v;							\
	fi;
	@echo $@ done

# project git merge
merge: project_merge ;
pmerge: project_merge ;
project_merge:: check_project
	@if [ -d ${PROJ_USR}/${PROJECT} -a -n "${BRANCH}" ]; then			\
		cd ${PROJ_SRC}/${PROJECT}						\
		&& echo ">>>> git merge --no-ff ${BRANCH}"				\
		&& git merge --no-ff ${BRANCH};						\
	else										\
		echo "Don't know what branch merge to current. Usage: make merge BRANCH=branch-to-merge";			\
	fi;
	@echo $@ done

# project git push
push: project_push ;
ppush: project_push ;
project_push:: check_project
	@if [ -d ${PROJ_USR}/${PROJECT} ]; then						\
		cd ${PROJ_SRC}/${PROJECT}						\
		&& echo ">>>> git push"							\
		&& git push;								\
	fi;
	@echo $@ done

# project git pull
pull: project_pull ;
ppull: project_pull ;
project_pull:: check_project
	@if [ -d ${PROJ_USR}/${PROJECT} ]; then						\
		cd ${PROJ_SRC}/${PROJECT}						\
		&& echo ">>>> git pull"							\
		&& git pull;								\
	fi;
	@echo $@ done

# install project into work directory
pin: project_install ;
project_install:: check_core_installed check_project
	@for PORT in ${PROJECT_REQUIRED}; do						\
		${MAKE} -s port_install PORT=$${PORT}					\
		|| exit 1;								\
	done;

	@if [ -d ${PROJ_USR}/${PROJECT} ]; then						\
		chmod -R u+w ${PROJ_USR}/${PROJECT};					\
	fi;

	@if [ -n "${RSYNC_COMMAND}" ]; then	\
		${RSYNC_COMMAND} -a --delete --delete-excluded --include='tags' --include '*.exe' --cvs-exclude --exclude '*.proto' ${PROJ_SRC}/${PROJECT}/* ${PROJ_USR}/${PROJECT};	\
	else 								\
		if [ -d ${PROJ_USR}/${PROJECT} ]; then							\
			rm -Rf    ${PROJ_USR}/${PROJECT};						\
		fi;											\
		mkdir ${PROJ_USR}/${PROJECT}								\
		&& cp ${PROJ_SRC}/${PROJECT}/config.mk ${PROJ_USR}/${PROJECT}/				\
		&& cp -R ${PROJ_SRC}/${PROJECT}/comps ${PROJ_USR}/${PROJECT}/				\
		&& cp -R ${PROJ_SRC}/${PROJECT}/conf ${PROJ_USR}/${PROJECT}/				\
		&& cp -R ${PROJ_SRC}/${PROJECT}/lib ${PROJ_USR}/${PROJECT}/				\
		&& cp -R ${PROJ_SRC}/${PROJECT}/services ${PROJ_USR}/${PROJECT}/			\
		&& find ${PROJ_USR}/${PROJECT}/ -depth -type d -name .svn -exec rm -Rf {} \;		\
		&& find ${PROJ_USR}/${PROJECT}/ -depth -type f -name '*.proto' -exec rm  -f {} \; ;	\
	fi

	@if [ \! -e ${PROJ_USR}/${PROJECT}/lib/Contenido ]; then			\
		mkdir ${PROJ_USR}/${PROJECT}/lib/Contenido;				\
	fi;

	@test -d ${PROJ_USR}/${PROJECT}/conf						\
	&& rm -Rf ${PROJ_USR}/${PROJECT}/conf						\
	|| true

	@if [ \! -e ${CORE_USR}/lib/${PROJECT} ]; then					\
		chmod    u+w ${CORE_USR}/lib						\
		&& ln -s ${PROJ_USR}/${PROJECT}/lib/${PROJECT}				\
			${CORE_USR}/lib/${PROJECT}					\
		&& chmod u-w ${CORE_USR}/lib;						\
	fi;

	@chmod -R a-w ${PROJ_USR}/${PROJECT}

	@for D in ${PROJ_TMP}/${PROJECT}						\
		  ${PROJ_VAR}/${PROJECT}/log						\
		  ${PROJ_VAR}/${PROJECT}/mason						\
		  ${PROJ_VAR}/${PROJECT}/run; do					\
		test -d $${D} || mkdir -p $${D};					\
	done;

	@echo $@ done
	
# deinstall project from work directory
pdi: project_deinstall ;
project_deinstall:: check_project_installed project_stop
	@if [ -d ${PROJ_USR}/${PROJECT} ]; then						\
		chmod -R u+w ${PROJ_USR}/${PROJECT}					\
		&& rm -Rf    ${PROJ_USR}/${PROJECT};					\
	fi;
	@if [ -d ${PROJ_TMP}/${PROJECT} ]; then						\
		rm -Rf ${PROJ_TMP}/${PROJECT};						\
	fi
	@if [ -d ${PROJ_VAR}/${PROJECT} ]; then						\
		rm -Rf ${PROJ_VAR}/${PROJECT};						\
	fi
	@echo $@ done

# commit plugins changes
plci: plugins_commit ;
plugins_commit:
ifdef PLUGIN
	@${MAKE} -s plugin_commit_${PLUGIN}
else
	@for P in ${PLUGINS}; do							\
		${MAKE} -s plugin_commit_$${P};						\
	done;
endif
	@echo $@ done

# commit plugin changes
plugin_commit_%:
ifeq (${VCS_TYPE},git)
	@cd ${PLUG_SRC}/${*} && git commit -a
else
	@svn ci ${PLUG_SRC}/${*}
endif
	@echo $@ done

# status of plugins sources via repository
plst: plugins_status ;
plugins_status:
ifdef PLUGIN
	@${MAKE} -s plugin_status_${PLUGIN}
else
	@for P in ${PLUGINS}; do							\
		${MAKE} -s plugin_status_$${P};						\
	done;
endif
	@echo $@ done

# status of plugin sources from repository
plugin_status_%:
ifeq (${VCS_TYPE},git)
	@cd ${PLUG_SRC}/${*} && git status
else
	@svn st -u ${PLUG_SRC}/${*}
endif
	@echo $@ done

# update plugins sources from repository
plup: plugins_update ;
plugins_update:
ifdef PLUGIN
	@${MAKE} -s plugin_update_${PLUGIN}
else
	@for P in ${PLUGINS}; do							\
		${MAKE} -s plugin_update_$${P};						\
	done;
endif
	@echo $@ done

# update plugin sources from repository
plugin_update_%:
ifeq (${VCS_TYPE},git)
	@cd ${PLUG_SRC}/${*} && git pull
else
	@svn up ${PLUG_SRC}/${*}
endif
	@echo $@ done

# plugins git checkout and branch switcher
plco: plugins_checkout ;
plugins_checkout:
ifdef PLUGIN
	@${MAKE} -s plugin_checkout_${PLUGIN}
else
	@for P in ${PLUGINS}; do							\
		${MAKE} -s plugin_checkout_$${P};					\
	done;
endif
	@echo $@ done

# plugin git checkout and branch switcher
plugin_checkout_%:
	@cd ${PLUG_SRC}/${*} && git checkout ${BRANCH};
	@echo $@ done

# plugins git branch workaround
plbranch: plugins_branch ;
plugins_branch:
ifdef PLUGIN
	@${MAKE} -s plugin_branch_${PLUGIN}
else
	@for P in ${PLUGINS}; do							\
		${MAKE} -s plugin_branch_$${P};						\
	done;
endif
	@echo $@ done

# plugin git checkout and branch switcher
plugin_branch_%:
	@if [ -n "${NAME}" -a -n "${FROM}" ]; then					\
		cd ${PLUG_SRC}/${*}							\
		&& git checkout -b ${NAME} ${FROM};					\
	elif [ -n "${NAME}" -a -n "${DELETE}" ]; then					\
		cd ${PLUG_SRC}/${*}							\
		&& git branch -d ${NAME};						\
	elif [ -n "${NAME}" ]; then							\
		cd ${PLUG_SRC}/${*}							\
		&& git checkout -b ${NAME};						\
	else										\
		cd ${PLUG_SRC}/${*}							\
		&& git branch -v;							\
	fi;
	@echo $@ done

# plugins git merge
plmerge: plugins_merge ;
plugins_merge:
ifdef PLUGIN
	@${MAKE} -s plugin_merge_${PLUGIN}
else
	@for P in ${PLUGINS}; do							\
		${MAKE} -s plugin_merge_$${P};						\
	done;
endif
	@echo $@ done

# plugin git checkout and branch switcher
plugin_merge_%:
	@cd ${PLUG_SRC}/${*} && git merge --no-ff ${BRANCH};
	@echo $@ done

# plugins git push
plush: plugins_push ;
plpush: plugins_push ;
plugins_push:
ifdef PLUGIN
	@${MAKE} -s plugin_push_${PLUGIN}
else
	@for P in ${PLUGINS}; do							\
		${MAKE} -s plugin_push_$${P};						\
	done;
endif
	@echo $@ done

# plugin git checkout and branch switcher
plugin_push_%:
	@cd ${PLUG_SRC}/${*} && git push;
	@echo $@ done

# plugins git pull
plull: plugins_pull ;
plpull: plugins_pull ;
plugins_pull:
ifdef PLUGIN
	@${MAKE} -s plugin_pull_${PLUGIN}
else
	@for P in ${PLUGINS}; do							\
		${MAKE} -s plugin_pull_$${P};						\
	done;
endif
	@echo $@ done

# plugin git checkout and branch switcher
plugin_pull_%:
	@cd ${PLUG_SRC}/${*} && git pull;
	@echo $@ done


# install plugins into work directory
plin: plugins_install ;
plugins_install: check_project_installed
#XXX It's workaround only (for old instalaltions - without usr/plugins)
	@test -d ${PLUG_USR} || mkdir ${PLUG_USR}
	@for P in ${PLUGINS}; do							\
		${MAKE} -s plugin_install_$${P};					\
	done;
	@echo $@ done

# install plugin
plugin_install_%:
	@if [ -d ${PLUG_USR}/${*} ]; then						\
		chmod -R u+w ${PLUG_USR}/${*};						\
	fi;
	@if [ -n "${RSYNC_COMMAND}" ]; then						\
		${RSYNC_COMMAND} -a --delete --delete-excluded				\
			--cvs-exclude --exclude '*.proto'				\
			${PLUG_SRC}/${*}/ ${PLUG_USR}/${*}/;				\
	else										\
		if [ -d ${PLUG_USR}/${*} ]; then					\
			rm -Rf ${PLUG_USR}/${*};					\
		fi;									\
		cp -R ${PLUG_SRC}/${*} ${PLUG_USR}/${*}					\
		&& find ${PLUG_USR}/${*}/ -depth -type d -name .svn			\
			-exec rm -Rf {} \;						\
		&& find ${PLUG_USR}/${*}/ -depth -type f -name '*.proto'		\
			-exec rm  -f {} \; ;						\
	fi;
	@chmod -R a-w ${PLUG_USR}/${*}
	@echo $@ done

# deinstall plugins from work directory
pldi: plugins_deinstall ;
plugins_deinstall:
	@for P in ${PLUGINS}; do							\
		${MAKE} -s plugin_deinstall_$${P};					\
	done;
	@echo $@ done

# deinstall plugin
plugin_deinstall_%:
	@if [ -d ${PLUG_USR}/${*} ]; then						\
		chmod -R u+w ${PLUG_USR}/${*}						\
		&& rm -Rf    ${PLUG_USR}/${*};						\
	fi;
	@echo $@ done

# create new plugin
plc: plugin_create ;
plugin_create: check_user
	@if [ -z "${NAME}" ]; then							\
		echo "ERROR: NAME not defined";						\
		echo "HINT:  use 'make cmd NAME=xxx'";					\
		exit 1;									\
	fi;
	@if [ -e ${PLUG_SRC}/${NAME} ]; then						\
		echo "ERROR: plugin ${NAME} already exists in src/plugins";		\
		echo "HINT:  select other name for new plugin";				\
		exit 1;									\
	fi;
	@if [ -e ${PLUG_USR}/${NAME} ]; then						\
		echo "ERROR: plugin ${NAME} already exists in usr/plugins";		\
		echo "HINT:  select other name for new plugin";				\
		exit 1;									\
	fi;

	@mkdir -p ${PLUG_SRC}								\
	&& cp -Rp ${CORE_SRC}/skel/plugin ${PLUG_SRC}/${NAME}				\
	&& find ${PLUG_SRC}/${NAME}/ -depth -type d -name .svn -exec rm -Rf {} \;	\
	&& find ${PLUG_SRC}/${NAME}/ -depth -type f -name '*.proto' -and		\
		\! -path '*/conf/*' -exec rm  -f {} \;

	@${call rewrite_skel,${CORE_SRC}/skel/plugin/lib/plugin/Apache.pm.proto,		\
			${PLUG_SRC}/${NAME}/lib/plugin/Apache.pm}
	@${call rewrite_skel,${CORE_SRC}/skel/plugin/lib/plugin/Init.pm.proto,			\
			${PLUG_SRC}/${NAME}/lib/plugin/Init.pm}
	@${call rewrite_skel,${CORE_SRC}/skel/plugin/lib/plugin/Keeper.pm.proto,		\
			${PLUG_SRC}/${NAME}/lib/plugin/Keeper.pm}
	@${call rewrite_skel,${CORE_SRC}/skel/plugin/lib/plugin/State.pm.proto,			\
			${PLUG_SRC}/${NAME}/lib/plugin/State.pm.proto}
	@${call rewrite_skel,${CORE_SRC}/skel/plugin/comps/contenido/plugin/dhandler,		\
			${PLUG_SRC}/${NAME}/comps/contenido/plugin/dhandler}
	@${call rewrite_skel,${CORE_SRC}/skel/plugin/comps/contenido/plugin/index.html,		\
			${PLUG_SRC}/${NAME}/comps/contenido/plugin/index.html}

	@mv ${PLUG_SRC}/${NAME}/lib/plugin ${PLUG_SRC}/${NAME}/lib/${NAME}
	@mv ${PLUG_SRC}/${NAME}/comps/contenido/plugin ${PLUG_SRC}/${NAME}/comps/contenido/${NAME}

	@echo $@ done


# install configs into work directory
conf: project_conf ;
project_conf:: check_plugins_installed
	@chmod -R u+w ${PROJ_USR}/${PROJECT}

	@if [ -d ${PROJ_USR}/${PROJECT}/conf ]; then					\
		rm -Rf  ${PROJ_USR}/${PROJECT}/conf;					\
	fi
	@mkdir   -p ${PROJ_USR}/${PROJECT}/conf/apache					\
	&& mkdir -p ${PROJ_USR}/${PROJECT}/conf/etc					\
	&& mkdir -p ${PROJ_USR}/${PROJECT}/conf/mason					\
	&& mkdir -p ${PROJ_USR}/${PROJECT}/conf/mod_perl

	@cp ${CORE_SRC}/conf/apache/mime.conf						\
	    ${CORE_SRC}/conf/apache/mime.types						\
	    ${PROJ_USR}/${PROJECT}/conf/apache/

	@${call rewrite,${CORE_SRC}/conf/apache/httpd.conf.proto,			\
			${PROJ_USR}/${PROJECT}/conf/apache/httpd.conf}
	@${call rewrite,${PROJ_SRC}/${PROJECT}/conf/apache/httpd.conf.proto,		\
			${PROJ_USR}/${PROJECT}/conf/apache/httpd_project.conf}

ifeq (${CRON_ENABLE},YES)
	@if [ -d ${PROJ_SRC}/${PROJECT}/conf/etc ]; then				\
		cd ${PROJ_SRC}/${PROJECT}/conf/etc &&					\
		for CTPROTO in crontab.`hostname`.proto crontab.proto; do		\
			if [ -f $$CTPROTO ]; then					\
				${call rewrite,$$CTPROTO,				\
					${PROJ_USR}/${PROJECT}/conf/etc/crontab};	\
				break;							\
			fi;								\
		done;									\
	fi
endif

	@${call rewrite,${CORE_SRC}/conf/mason/handler.pl.proto,			\
			${PROJ_USR}/${PROJECT}/conf/mason/handler.pl}
	@${call rewrite,${PROJ_SRC}/${PROJECT}/conf/mason/handler.pl.proto,		\
			${PROJ_USR}/${PROJECT}/conf/mason/handler_project.pl}

	@${call rewrite,${CORE_SRC}/conf/mod_perl/startup.pl.proto,			\
			${PROJ_USR}/${PROJECT}/conf/mod_perl/startup.pl}
	@${call rewrite,${PROJ_SRC}/${PROJECT}/conf/mod_perl/startup.pl.proto,		\
			${PROJ_USR}/${PROJECT}/conf/mod_perl/startup_project.pl}

	@${call rewrite,${CORE_SRC}/conf/mason/Config.pm.proto,				\
			${PROJ_USR}/${PROJECT}/conf/mason/Config.pm}
	@${call rewrite,${CORE_SRC}/lib/Contenido/State.pm.proto,			\
			${PROJ_USR}/${PROJECT}/lib/Contenido/State.pm}
	@${call rewrite,${CORE_SRC}/lib/Modules.pm.proto,				\
			${PROJ_USR}/${PROJECT}/lib/Modules.pm}

	@${call rewrite,${PROJ_SRC}/${PROJECT}/lib/${PROJECT}/State.pm.proto,		\
			${PROJ_USR}/${PROJECT}/lib/${PROJECT}/State.pm}

	@chmod -R u+w ${CORE_USR}/lib ${CORE_USR}/services

	@${call rewrite,${CORE_SRC}/services/inc.pl.proto,				\
			${CORE_USR}/services/inc.pl}

	@chmod -R a-w ${CORE_USR}/lib ${CORE_USR}/services

	@for P in ${PLUGINS}; do							\
		chmod -R u+w ${PLUG_USR}/$${P};						\
		${call rewrite,${PLUG_SRC}/$${P}/lib/$${P}/State.pm.proto,		\
			${PLUG_USR}/$${P}/lib/$${P}/State.pm};				\
		chmod -R u-w ${PLUG_USR}/$${P};						\
	done;

	@if [ $$((`perl -e 'print "".(lc "${DEVELOPMENT}" eq "yes" ? 1 : 0);'`)) -ne 1 ]; then 	\
		${CORE_USR}/services/pregen							\
			${PROJ_SRC} ${PROJ_USR} ${PROJECT} '${PREGEN_GLOB}' ${PREGEN_LIST};	\
	fi

	@chmod -R a-w ${PROJ_USR}/${PROJECT}


ifeq (${DISABLE},YES)
	@crontab -l | sed 's/^#*/#/' | crontab -;					\
	echo "Disabled crontab"
else
	@if [ -f ${PROJ_USR}/${PROJECT}/conf/etc/crontab ]; then			\
		crontab ${PROJ_USR}/${PROJECT}/conf/etc/crontab;			\
		echo "Installed crontab from: ${PROJ_USR}/${PROJECT}/conf/etc/crontab";	\
	fi
endif

	@echo $@ done

# rsync project static files directly to frontend
prs: project_rsync ;
project_rsync:: check_project
	@for D in ${RSYNC_DIRS}; do							\
		if [ -d ${RSYNC_ROOT}/$${D} ]; then					\
			D=$${D}/;							\
		elif [ \! -f ${RSYNC_ROOT}/$${D} ]; then				\
			echo "ERROR: no such dir or file: ${RSYNC_ROOT}/$${D}";		\
			exit 1;								\
		fi;									\
		for S in ${RSYNC_SERVERS}; do						\
			echo "#######################################";			\
			echo "# rsync $${D} to $${S}";					\
			echo "#######################################";			\
			cd ${RSYNC_ROOT} && ${RSYNC} -rtRv				\
				--delete --delete-excluded --exclude .svn --chmod=u+w	\
			$${D} $${S};							\
			echo -e "done\n";						\
		done;									\
	done;
	@echo $@ done

# rsync core static files directly to frontend
crs: core_rsync ;
core_rsync:: check_core_installed
	@for D in ${RSYNC_CORE_DIRS}; do						\
		if [ -d ${RSYNC_CORE_ROOT}/$${D} ]; then				\
			D=$${D}/;							\
		elif [ \! -f ${RSYNC_CORE_ROOT}/$${D} ]; then				\
			echo "ERROR: no such dir or file: ${RSYNC_CORE_ROOT}/$${D}";	\
			exit 1;								\
		fi;									\
		for S in ${RSYNC_SERVERS}; do						\
			echo "#######################################";			\
			echo "# rsync $${D} to $${S}";					\
			echo "#######################################";			\
			cd ${RSYNC_CORE_ROOT} && ${RSYNC} -rtRv				\
				--delete --delete-excluded --exclude .svn --chmod=u+w	\
			$${D} $${S};							\
			echo -e "done\n";						\
		done;									\
	done;
	@echo $@ done

assets: project_assets ;
project_assets:: check_project
	@rm -rf ${ASSETS_ROOT}/assets;
	@cd ${PROJ_SRC}/${PROJECT} && echo ${PROJ_SRC}/${PROJECT} &&			\
	npm install;
	@cd ${PROJ_SRC}/${PROJECT} && npm run build;
	@if [ -d ${ASSETS_ROOT}/assets ]; then						\
		echo "Assets generated in ${ASSETS_ROOT}/assets";			\
	fi;
	@echo $@ done

assdev: project_assets_dev ;
project_assets_dev:: check_project
	@rm -rf ${ASSETS_ROOT}/assets;
	@cd ${PROJ_SRC}/${PROJECT} && echo ${PROJ_SRC}/${PROJECT} &&			\
	npm install;
	@cd ${PROJ_SRC}/${PROJECT} && npm run dev;

# rsync project assets directly to frontend
ars: project_assets_rsync ;
project_assets_rsync:: check_project
	@if [ -d ${ASSETS_ROOT}/assets ]; then						\
		echo "Found assets in ${ASSETS_ROOT}/assets";				\
		for S in ${RSYNC_SERVERS}; do						\
			echo "#######################################################";	\
			echo "# rsync ${ASSETS_ROOT}/assets to $${S}";			\
			echo "#######################################################";	\
			cd ${ASSETS_ROOT} && ${RSYNC} -rtRv				\
				--delete --delete-excluded --exclude .svn --chmod=u+w	\
			assets $${S};							\
			echo -e "done\n";						\
		done;									\
	elif [ \! -f ${ASSETS_ROOT} ]; then						\
		echo "ERROR: no such dir or file: ${ASSETS_ROOT}";			\
		exit 1;									\
	fi;
	@echo $@ done

# start project
start: project_start ;
ifneq (${DISABLE},YES)
ifeq (${DB_TYPE},SINGLE)
project_start::	pgsql_start	apache_start
	@echo $@ done
else
project_start::	apache_start
	@echo $@ done
endif
else
project_start::
	@for M in `cd ${PROJ_VAR}/${PROJECT} && ls -d mason.* 2>/dev/null`; do          \
		echo "cleaning old mason files: $$M";                                   \
		rm -Rf ${PROJ_VAR}/${PROJECT}/$$M;                                      \
	done;
	@echo $@ disabled
endif
	
# stop project
stop: project_stop ;
project_stop:: apache_stop
	@echo $@ done

# full reinstall & restart core & project
full: project_fullreload ;
project_fullreload:: project_stop mason_clean core_update core_install			\
	project_update project_install plugins_update plugins_install			\
	project_conf project_start
	@echo $@ done

# full reinstall & restart project
reload: project_reload ;
project_reload:: project_stop mason_clean project_update project_install		\
	plugins_update plugins_install project_conf project_start
	@echo $@ done

# restart project without svn update
nano: project_rewind ;
rewind: project_rewind ;
project_rewind:: project_stop mason_clean project_install plugins_install		\
	project_conf project_start
	@echo $@ done

# clean all mason temporaries & restart project
refresh: project_refresh ;
project_refresh:: project_stop mason_clean project_start
	@echo $@ done

# create new project
create: project_create ;
project_create: check_user
	@if [ -z "${NAME}" ]; then							\
		echo "ERROR: NAME not defined";						\
		echo "HINT:  use 'make cmd NAME=xxx'";					\
		exit 1;									\
	fi;
	@if [ -e ${PROJ_SRC}/${NAME} ]; then						\
		echo "ERROR: project ${NAME} already exists in src/projects";		\
		echo "HINT:  select other name for new project";			\
		exit 1;									\
	fi;
	@if [ -e ${PROJ_USR}/${NAME} ]; then						\
		echo "ERROR: project ${NAME} already exists in usr/projects";		\
		echo "HINT:  select other name for new project";			\
		exit 1;									\
	fi;

	@cp -Rp ${CORE_SRC}/skel/project ${PROJ_SRC}/${NAME}				\
	&& find ${PROJ_SRC}/${NAME}/ -depth -type d -name .svn -exec rm -Rf {} \;	\
	&& find ${PROJ_SRC}/${NAME}/ -depth -type f -name '*.proto' -and		\
		\! -path '*/conf/*' -exec rm  -f {} \;

	@${call rewrite_skel,${CORE_SRC}/skel/project/lib/project/Apache.pm.proto,			\
			${PROJ_SRC}/${NAME}/lib/project/Apache.pm}
	@${call rewrite_skel,${CORE_SRC}/skel/project/lib/project/Init.pm.proto,			\
			${PROJ_SRC}/${NAME}/lib/project/Init.pm}
	@${call rewrite_skel,${CORE_SRC}/skel/project/lib/project/Keeper.pm.proto,			\
			${PROJ_SRC}/${NAME}/lib/project/Keeper.pm}
	@${call rewrite_skel,${CORE_SRC}/skel/project/lib/project/SampleCustomDocument.pm.proto,	\
			${PROJ_SRC}/${NAME}/lib/project/SampleCustomDocument.pm}
	@${call rewrite_skel,${CORE_SRC}/skel/project/lib/project/SampleDefaultDocument.pm.proto,	\
			${PROJ_SRC}/${NAME}/lib/project/SampleDefaultDocument.pm}
	@${call rewrite_skel,${CORE_SRC}/skel/project/lib/project/State.pm.proto,			\
			${PROJ_SRC}/${NAME}/lib/project/State.pm.proto}
	@${call rewrite_skel,${CORE_SRC}/skel/project/lib/project/SQL/SampleTable.pm.proto,		\
			${PROJ_SRC}/${NAME}/lib/project/SQL/SampleTable.pm}
	@${call rewrite_skel,${CORE_SRC}/skel/project/lib/project/SQL/SampleTable.pm.proto,		\
			${PROJ_SRC}/${NAME}/lib/project/SQL/SampleTable.pm}
	@${call rewrite_skel,${CORE_SRC}/skel/project/comps/www/index.html.proto,			\
			${PROJ_SRC}/${NAME}/comps/www/index.html}
	@${call rewrite_skel,${CORE_SRC}/skel/project/conf/etc/crontab.tmpl.proto,			\
			${PROJ_SRC}/${NAME}/conf/etc/crontab.tmpl.proto}
	@${call rewrite_skel,${CORE_SRC}/skel/project/config.mk.proto,					\
			${PROJ_SRC}/${NAME}/config.mk}

	@mv ${PROJ_SRC}/${NAME}/lib/project ${PROJ_SRC}/${NAME}/lib/${NAME}

	@echo $@ done


# change active project
swi:    project_switch ;
switch: project_switch ;
project_switch:
	@if [ -z "${NAME}" ]; then							\
		echo "ERROR: NAME not defined";						\
		echo "HINT:  use 'make cmd NAME=xxx'";					\
		exit 1;									\
	fi;
	@if [ "${NAME}" = "${PROJECT}" ]; then						\
		echo "ERROR: project ${NAME} is already active";			\
		exit 1;									\
	fi;
	@if [ \! -d ${PROJ_SRC}/${NAME} ]; then						\
		echo "ERROR: project ${NAME} doesn't exists in src/projects";		\
		echo "HINT:  checkout sources for project ${NAME}";			\
		exit 1;									\
	fi;
	@${MAKE} -s project_stop
	@perl -pi.orig -e 's|^([[:space:]]*PROJECT[[:space:]]*\?*\=[[:space:]]*)[^[:space:]]+([[:space:]]*)$$|$$1${NAME}$$2|' ${ROOT_DIR}/config.mk
	@${MAKE} -s project_reload PROJECT=${NAME}

	@echo $@ done

# backing-up project sources
backup: project_backup ;
project_backup:: check_project
	@echo "compressing ${PROJECT} sources => ${PROJ_VAR}/${PROJECT}/${PROJECT}.src.tgz"
	@tar -czf ${PROJ_VAR}/${PROJECT}/${PROJECT}.src.tgz -C ${PROJ_SRC} ${PROJECT}
	@echo $@ done

# import project sources into repository
import: project_import ;
project_import: check_project
	@if [ $$((`find ${PROJ_SRC}/${PROJECT} -type d -name .svn | wc -l`)) -ne 0 ]; then	\
		echo "ERROR: project '${PROJECT}' seems as already imported";			\
		exit 1;										\
	fi
	@if ! svn ls ${SVN_REPOSITORY}/${PROJECT}/trunk >&- 2>&-; then				\
		echo "ERROR: no repository for project '${PROJECT}' found";			\
		echo "HINT: contact with respository administrators.";				\
		exit 1;										\
	fi
	@if [ $$((`svn ls ${SVN_REPOSITORY}/${PROJECT}/trunk | wc -l`)) -ne 0 ]; then		\
		echo "ERROR: repository for project '${PROJECT}' isn't empty";			\
		echo "Please contact with respository administrators.";				\
		exit 1;										\
	fi
	@if svn import ${PROJ_SRC}/${PROJECT} ${SVN_REPOSITORY}/${PROJECT}/trunk		\
	&&  mv ${PROJ_SRC}/${PROJECT} ${PROJ_SRC}/${PROJECT}.before-import			\
	&&  svn checkout ${SVN_REPOSITORY}/${PROJECT}/trunk ${PROJ_SRC}/${PROJECT}; then	\
		echo "Your project directory moved to '${PROJ_SRC}/${PROJECT}.before-import'";	\
		echo "Directory '${PROJ_SRC}/${PROJECT}' is now working copy";			\
	else											\
		echo "ERROR: some errors occured during import/checkout project '${PROJECT}'";	\
		echo "HINT: contact with respository administrators.";				\
		exit 1;										\
	fi
	@echo $@ done

# create user (editors)
user: project_user ;
project_user: check_core_installed pgsql_template
	@export PGPASSWORD=${BASE_PASSWD} && ${CORE_USR}/services/createuser |		\
	${PSQL} -h '${BASE_HOST}' -p ${PGSQL_PORT} -U ${BASE_USER} ${PGSQL_BASE}
	@echo $@ done

##################
# apache_* targets
##################

#	_exp=`perl -e 'print $1 if "${LIMIT_VMEMORY_HTTPD}" =~ /.*(.)$/;'`; 
#	_exp=`perl -e 'my $$e = ("${LIMIT_VMEMORY_HTTPD}"=~/.*(.)/)[0]; print $$e;'`; \
#	echo _exp=$${_exp};						\

apache_start: check_conf_installed
	@${call is_alive,${PROJ_VAR}/${PROJECT}/run/httpd.pid};				\
	FLAGS=`perl -e 'print " -DDEVELOPMENT" if lc "${DEVELOPMENT}" eq "yes";'`;	\
	FLAGS=$$FLAGS`perl -e '								\
		if    (lc "${RSYSLOG_ENABLE}"  eq "yes") { print " -DRSYSLOG";  }	\
		elsif (lc "${CRONOLOG_ENABLE}" eq "yes") { print " -DCRONOLOG"; }	\
		else                                     { print " -DFILELOG";  }'`;	\
	if [ "${LIMIT_VMEMORY_HTTPD}" ]; then						\
		if [ x`uname` = x"FreeBSD" ]; then					\
			LIMITS="${LIMIT_CMD} -v ${LIMIT_VMEMORY_HTTPD}";		\
		else									\
#			echo "LIMIT_VMEMORY_HTTPD=${LIMIT_VMEMORY_HTTPD}";		\
			_exp=`expr "${LIMIT_VMEMORY_HTTPD}" : '.*\(.\)'`;		\
#			echo _exp=$${_exp};						\
			_value=`expr "${LIMIT_VMEMORY_HTTPD}" : '\(.*\).'`;		\
#			echo _value=$${_value};						\
			if [ "$${_exp}" = "m" ]; then					\
				_value=`expr $$_value \* 1024 `;			\
			fi;								\
#			echo _value=$${_value};						\
			LIMITS="ulimit -S -v $${_value}";				\
			echo "DEBUG: running on Linux, LIMITS='$${LIMITS}'"; \
		fi;									\
	fi;										\
	if [ "$${ALIVE}" = "YES" ]; then						\
		echo "WARNING: apache for project '${PROJECT}' already running";	\
	else										\
		[ x`uname` = x"Linux" ] && $${LIMITS} && LIMITS=""; \
		if $${LIMITS} ${LOCAL}/apache/bin/httpd $${FLAGS}			\
			-d ${PROJ_USR}/${PROJECT}/					\
			-f ${PROJ_USR}/${PROJECT}/conf/apache/httpd.conf; then		\
			echo -n "apache for project '${PROJECT}' started";		\
			if [ "${LIMIT_VMEMORY_HTTPD}" ]; then				\
				echo " (with vmem limit: ${LIMIT_VMEMORY_HTTPD})";	\
			else								\
				echo;							\
			fi;								\
		else									\
			echo "ERROR: can't start apache for project '${PROJECT}'";	\
			exit 1;								\
		fi;									\
	fi;
	@for M in `cd ${PROJ_VAR}/${PROJECT} && ls -d mason.*`; do                      \
		echo "cleaning old mason files: $$M";                                   \
		rm -Rf ${PROJ_VAR}/${PROJECT}/$$M;                                      \
	done;
	@echo $@ done

apache_stop: check_conf_installed
	@${call is_alive,${PROJ_VAR}/${PROJECT}/run/httpd.pid};				\
	if [ "$${ALIVE}" = "YES" ]; then						\
		kill `head -n 1 ${PROJ_VAR}/${PROJECT}/run/httpd.pid`;			\
		${call wait_stop,${PROJ_VAR}/${PROJECT}/run/httpd.pid,apache};		\
		if [ $${STOPPED} != 'YES' ]; then					\
			echo "ERROR: can't stop apache for project '${PROJECT}'";	\
			exit 1;								\
		else									\
			echo "apache for project '${PROJECT}' stopped";			\
		fi;									\
	else										\
		echo "WARNING: apache for project '${PROJECT}' isn't running";		\
	fi;
	@echo $@ done

alog: apache_access_log ;
apache_access_log:
	@test -e ${PROJECT_LOG}/access_log || touch ${PROJECT_LOG}/access_log
	@tail -F ${PROJECT_LOG}/access_log

palog: apache_pager_access_log ;
apache_pager_access_log:
	@test -e ${PROJECT_LOG}/access_log || touch ${PROJECT_LOG}/access_log
	@${PAGER} ${PROJECT_LOG}/access_log

elog: apache_error_log ;
apache_error_log:
	@test -e ${PROJECT_LOG}/error_log || touch ${PROJECT_LOG}/error_log
	@tail -F ${PROJECT_LOG}/error_log

pelog: apache_pager_error_log ;
apache_pager_error_log:
	@test -e ${PROJECT_LOG}/error_log || touch ${PROJECT_LOG}/error_log
	@${PAGER} ${PROJECT_LOG}/error_log

#################
# pgsql_* targets
#################

ifeq (${DB_TYPE},SINGLE)

pgsql_init: check_user
	@cd ${PORTSDIR}/all/postgresql							\
	&& ${MAKE} -s initdb PREFIX=${LOCAL} PORTSWRK=${PORTSWRK}
	@echo $@ done

pgsql_start: pgsql_init
	@${call is_alive,${LOCAL}/pgsql/data/postmaster.pid};				\
	if [ "$${ALIVE}" = "YES" ]; then						\
		echo "WARNING: postgresql already running";				\
	else										\
		if ${LOCAL}/pgsql/bin/pg_ctl -w -D ${LOCAL}/pgsql/data start; then	\
			echo "postgresql started";					\
		else									\
			echo "ERROR: can't start postgresql";				\
			exit 1;								\
		fi;									\
	fi;
	@echo $@ done

pgsql_stop: check_user
	@${call is_alive,${LOCAL}/pgsql/data/postmaster.pid};				\
	if [ "$${ALIVE}" = "YES" ]; then						\
		${LOCAL}/pgsql/bin/pg_ctl -w -m fast -D ${LOCAL}/pgsql/data stop;	\
		${call wait_stop,${LOCAL}/pgsql/data/postmaster.pid,postgresql};	\
		if [ $${STOPPED} != 'YES' ]; then					\
			echo "ERROR: can't stop postgresql";				\
			exit 1;								\
		else									\
			echo "postgresql stopped";					\
		fi;									\
	else										\
		echo "WARNING: postgresql isn't running";				\
	fi;
	@echo $@ done

pgsql_create: pgsql_start
	@if [ $$((`${PSQL} -p ${PGSQL_PORT} -l |					\
		perl -ne 'print $$_ if /^\s*${PGSQL_BASE}/' | wc -l`)) -eq 0 ]; then	\
		${LOCAL}/pgsql/bin/createuser -SdR -p ${PGSQL_PORT} ${BASE_USER}	\
		|| true;								\
		${LOCAL}/pgsql/bin/createdb -p ${PGSQL_PORT} -O ${BASE_USER}		\
		${PGSQL_BASE};								\
		echo "ALTER USER ${BASE_USER} PASSWORD '${BASE_PASSWD}';" |		\
		${PSQL} -p ${PGSQL_PORT} ${PGSQL_BASE};					\
		${PSQL} -p ${PGSQL_PORT} ${PGSQL_BASE} < ${LOCAL}/pgsql/share/contrib/_int.sql;	\
	else										\
		echo "WARNING: database ${PGSQL_BASE} already exists";			\
	fi;
	@echo $@ done


else

pgsql_init										\
pgsql_start										\
pgsql_stop										\
pgsql_create:
	@echo "ERROR: $@ not implemented for DB_TYPE: ${DB_TYPE}";			\
	echo "HINT:  use 'make cmd DB_TYPE=xxx' or edit ${ROOT_DIR}/config.mk";		\
	exit 1

endif

ifeq (${DB_TYPE},SINGLE)
pgsql_template: pgsql_create
else
pgsql_template: check_project
endif
	@if [ $$((`export PGPASSWORD=${BASE_PASSWD} && ${PSQL} -h '${BASE_HOST}'	\
		-p ${PGSQL_PORT} -U ${BASE_USER} -c '\d' ${PGSQL_BASE} |		\
		grep documents | wc -l`)) -lt 1 ]; then					\
		export PGPASSWORD=${BASE_PASSWD} && ${PSQL} -h '${BASE_HOST}'		\
		-p ${PGSQL_PORT} -U ${BASE_USER} ${PGSQL_BASE} <			\
		${CORE_SRC}/sql/${STORE_METHOD}/contenido.sql;				\
	else										\
		echo "WARNING: template already loaded into database ${PGSQL_BASE}";	\
	fi;

	@echo $@ done

psql: pgsql_psql ;
ifeq (${DB_TYPE},SINGLE)
pgsql_psql: pgsql_create
else
pgsql_psql: check_project
endif
	@(export PGPASSWORD=${BASE_PASSWD} && cd ../.. && ${PSQL} -h '${BASE_HOST}' -p ${PGSQL_PORT}	\
	-U ${BASE_USER} ${PGSQL_BASE}) 

# dump project database
dump:   pgsql_dump ;
ifeq (${DB_TYPE},NONE)
pgsql_dump:
	@echo "project ${PROJECT} hasn't database"; exit 1
else
ifeq (${DB_TYPE},SINGLE)
pgsql_dump: pgsql_create
else
pgsql_dump: check_project
endif
	@echo "dumping ${BASE_HOST}:${PGSQL_PORT}/${PGSQL_BASE} => ${PROJ_VAR}/${PROJECT}/${PGSQL_BASE}.sql"
	@export PGPASSWORD=${BASE_PASSWD} && ${PGDUMP} -Ox -h '${BASE_HOST}' -p ${PGSQL_PORT}	\
	-U ${BASE_USER} ${PGSQL_BASE} > ${PROJ_VAR}/${PROJECT}/${PGSQL_BASE}.sql
	@echo $@ done
endif

# dump project database (gzip)
dumpz:   pgsql_dumpz ;
ifeq (${DB_TYPE},NONE)
pgsql_dumpz:
	@echo "project ${PROJECT} hasn't database"; exit 1
else
ifeq (${DB_TYPE},SINGLE)
pgsql_dumpz: pgsql_create
else
pgsql_dumpz: check_project
endif
	@echo "dumping ${BASE_HOST}:${PGSQL_PORT}/${PGSQL_BASE} => ${PROJ_VAR}/${PROJECT}/${PGSQL_BASE}.sql.gz"
	@export PGPASSWORD=${BASE_PASSWD} && ${PGDUMP} -Ox -h '${BASE_HOST}' -p ${PGSQL_PORT}	\
	-U ${BASE_USER} ${PGSQL_BASE} | gzip > ${PROJ_VAR}/${PROJECT}/${PGSQL_BASE}.sql.gz
	@echo $@ done
endif


########################
# internal targets
# (not for direct usage)
########################

mason_clean:
	@mv -f ${PROJ_VAR}/${PROJECT}/mason                                             \
		${PROJ_VAR}/${PROJECT}/mason.`date +%Y-%m-%d.%H:%M:%S`                  \
	&& mkdir ${PROJ_VAR}/${PROJECT}/mason;
	@echo $@ done


#################
# check_* targets
#################

# it's required
check_user: check_owner ;

# if user is installation owner?
check_owner:
	@if [ `whoami` != ${OWNER} ]; then						\
		echo "ERROR: please run as OWNER: ${OWNER}";				\
		echo "HINT:  use 'sudo -u ${OWNER} -H bash' or 'sudo -i -u ${OWNER}'";	\
		exit 1;									\
	fi;

# check if core installed
check_core_installed: check_user
	@if [ $$((`ls -1A ${CORE_USR}/ | wc -l`)) -eq 0 ]; then				\
		echo "ERROR: core not installed";					\
		echo "HINT:  use 'make core_install' or 'make cin'";			\
		exit 1;									\
	fi;

# check for existing project (see include near line ~30)
check_project: check_user
	@if [ -z "${PROJECT}" ]; then							\
		echo "ERROR: project not defined";					\
		echo "HINT:  use 'make cmd PROJECT=xxx' or edit ${ROOT_DIR}/config.mk";	\
		exit 1;									\
	fi;

# check if project installed
check_project_installed: check_project
	@if [ \! -d ${PROJ_USR}/${PROJECT} ]; then 					\
		echo "ERROR: project '${PROJECT}' not installed";			\
		echo "HINT:  use 'make project_install' or 'make pin'";			\
		exit 1;									\
	fi;
	@if [ $$((`ls -1A ${PROJ_USR}/${PROJECT} | wc -l`)) -eq 0 ]; then		\
		echo "ERROR: project '${PROJECT}' not installed";			\
		echo "HINT:  use 'make project_install' or 'make pin'";			\
		exit 1;									\
	fi;

# check if plugins installed
check_plugins_installed: check_project_installed
	@for P in ${PLUGINS}; do							\
		if [ \! -d ${PLUG_USR}/$${P} ]; then					\
			echo "ERROR: plugin '$${P}' not installed";			\
			echo "HINT:  use 'make plugins_install' or 'make plin'";	\
			exit 1;								\
		fi;									\
	done;

# check if configs installed
check_conf_installed: check_project_installed
	@if [ \! -d ${PROJ_USR}/${PROJECT}/conf ]; then 				\
		echo "ERROR: configs for project '${PROJECT}' not installed";		\
		echo "HINT:  use 'make project_conf' or 'make conf'";			\
		exit 1;									\
	fi;


##########################
# port_* & ports_* targets
##########################

# single port sub-commands
port_%: check_user
ifdef PORT
	@cd ${PORTSDIR}/all/${PORT}							\
	&& ${MAKE} -s $* PREFIX=${LOCAL} PORTSWRK=${PORTSWRK}
ifndef DRY_RUN
	@echo $@ done
endif
else
	@echo "ERROR: no PORT defined";							\
	echo "HINT:  use 'make cmd PORT=name'";						\
	exit 1;
endif

# multiple ports sub-commands
ports_%: check_user
	@cd ${PORTSDIR}									\
	&& ${MAKE} -s $* PREFIX=${LOCAL} PORTSWRK=${PORTSWRK}
	@echo $@ done


########
# macros
########
define is_alive
	if [ \! -f ${1} ]; then								\
		ALIVE='NO';								\
	else										\
		if kill -0 `head -n 1 ${1}` 2>/dev/null; then				\
			ALIVE='YES';							\
		else									\
			rm -f ${1};							\
			ALIVE='NO';							\
		fi;									\
	fi
endef

define wait_stop
	TRYMAX=`test -z "${3}" && echo 10 || echo ${3}`;				\
	TRYCUR=1;									\
	STOPPED='NO';									\
	echo -n "Waiting for ${2} stopped, tries: $${TRYCUR}";				\
	${call is_alive,${1}};								\
	while [ "$${ALIVE}" = "YES" -a $$(($${TRYCUR})) -lt $$(($${TRYMAX})) ]; do	\
		sleep 1;								\
		TRYCUR=$$(($${TRYCUR}+1));						\
		echo -n " $${TRYCUR}";							\
		${call is_alive,${1}};							\
	done;										\
	echo "";									\
	if [ "$${ALIVE}" = "NO" ]; then							\
		STOPPED='YES';								\
	fi
endef

ifeq (${USE_MTT},YES)
define rewrite
	$(foreach R, ${REWRITE}, MTT_${R}="${${R}}")					\
	${CORE_SRC}/services/mttbfr > ${PROJ_TMP}/${PROJECT}/mtt.conf &&		\
	${CORE_SRC}/services/mttcomp < ${1} |						\
	${LOCAL}/bin/mtt -b ${PROJ_TMP}/${PROJECT}/mtt.conf - ${2}			\
	&& echo "created ${2} (mtt)"
endef
else
define rewrite
	$(foreach R, ${REWRITE}, ${R}="${${R}}")					\
	perl -pe 's/@([A-Z_]+)@/$$ENV{$$1}/ge' < ${1} > ${2}				\
	&& echo "created ${2} (rewrite)"
endef
endif

define rewrite_skel
	NAME=${NAME}									\
	LOCAL=@LOCAL@									\
	CORE_USR=@CORE_USR@								\
	PROJ_USR=@PROJ_USR@								\
	PROJECT_VAR=@PROJECT_VAR@							\
	perl -pe 's/@([A-Z_]+)@/$$ENV{$$1}/ge' < ${1} > ${2}				\
	&& echo "created ${2}"
endef

# rewrites values
PREFIX =		${LOCAL}
ROOT_LOG =		${ROOT_DIR}/var/log
PGSQL_REDIRECT =	${shell perl -e 'print lc("${PGSQL_LOGGING}") eq "yes" && "on"  || "off"'}
ifdef PROJECT
PROJECT_USR =		${PROJ_USR}/${PROJECT}
PROJECT_TMP =		${PROJ_TMP}/${PROJECT}
PROJECT_VAR =		${PROJ_VAR}/${PROJECT}
PROJECT_LOG =		${PROJ_VAR}/${PROJECT}/log
PROJECT_RUN =		${PROJ_VAR}/${PROJECT}/run
endif

# rewrites definitions
REWRITE +=										\
		AUTH_COOKIE								\
		AUTH_MEMCACHED_BUSY_LOCK						\
		AUTH_MEMCACHED_ENABLE							\
		AUTH_MEMCACHED_SERVERS							\
		BASE_HOST								\
		BASE_PASSWD								\
		BASE_USER								\
		BINARY									\
		CASCADE									\
		COMP_CACHE_ENABLED							\
		COMP_TIMINGS_DISABLE							\
		COMPOSITE								\
		CONF									\
		CONTENIDO_VERSION							\
		CONVERT									\
		CORE_COMP								\
		CORE_SRC								\
		CORE_VERSION								\
		CORE_USR								\
		CRONOLOG_ENABLE								\
		CRONOLOG_FORMAT								\
		CROSSLINKS								\
		DB_TYPE									\
		DEBUG_FORMAT								\
		DEBUG_MIN_LEVEL								\
		DEBUG_MAX_LEVEL								\
		DEBUG_STACK_TRACE							\
		DEBUG									\
		DEBUG_CORE								\
		DEBUG_SQL								\
		DEBUG_WORKTIME								\
		DEFAULT_ESCAPE_FLAGS							\
		DEFAULT_HANDLER								\
		DEVELOPMENT								\
		ERROR_MODE								\
		FILES									\
		FILE_WEB_STORAGE							\
		HOSTNAME								\
		HTTPD_DOCS								\
		HTTPD_ELOG_LEVEL							\
		HTTPD_PORT								\
		HTTPD_SERVER								\
		IMAGES									\
		LISTEN_BACK_LOG								\
		LOCAL									\
		LOCALE									\
		LOGGER									\
		MASON_CACHE_ENABLED							\
		MASON_COMP								\
		MASON_MEMCACHED_BACKEND							\
		MASON_MEMCACHED_DEBUG							\
		MASON_MEMCACHED_ENABLED							\
		MASON_MEMCACHED_NAMESPACE						\
		MASON_MEMCACHED_SERVERS							\
		MASTER_BASE_HOST							\
		MASTER_BASE_NAME							\
		MASTER_BASE_PASSWD							\
		MASTER_BASE_PORT							\
		MASTER_BASE_USER							\
		MAX_CLIENTS								\
		MAX_PROCESS_SIZE							\
		MAX_REQUESTS_PER_CHILD							\
		MAX_SPARE_SERVERS							\
		MEMCACHED_BACKEND							\
		MEMCACHED_DELAYED							\
		MEMCACHED_ENABLE							\
		MEMCACHED_ENABLE_COMPRESS						\
		MEMCACHED_SELECT_TIMEOUT						\
		MEMCACHED_SERVERS							\
		MEMCACHED_SET_MODE							\
		MIN_SPARE_SERVERS							\
		MODULES									\
		MULTIDOMAIN									\
		OPTIONS_EXPIRE								\
		PERL_LEVEL								\
		PERL_LIB								\
		PERSISTENT_CONN								\
		PGSQL_BASE								\
		PGSQL_CLIENT_ENCODING							\
		PGSQL_PORT								\
		PGSQL_REAL_PREPARE							\
		PGSQL_REDIRECT								\
		PGSQL_CLIENT_ENCODING							\
		PGSQL_ENCODE_DATA							\
		PGSQL_DECODE_DATA							\
		PGSQL_ENABLE_UTF							\
		SERIALIZE_WITH								\
		PLUG_SRC								\
		PLUGINS									\
		PLUGIN_COMP								\
		PREAMBLE_HANDLER							\
		PREAMBLE_HANDLER_PATH							\
		PREFIX									\
		PRELOADS								\
		PREVIEW									\
		PROFILING_DBI								\
		PROJECT									\
		PROJECT_HOME								\
		PROJECT_LC								\
		PROJECT_NAME								\
		PROJECT_LOG								\
		PROJECT_RUN								\
		PROJECT_TMP								\
		PROJECT_USR								\
		PROJECT_VAR								\
		PROJECT_VERSION								\
		PROJ_SRC								\
		PROJ_USR								\
		ROOT_LOG								\
		READONLY								\
		RSYSLOG_ENABLE								\
		RSYSLOG_HOST								\
		SERVER_ADMIN								\
		SESSIONS								\
		SPARE_REAPER_DELAY							\
		SPARE_REAPER_DELAY_FAKEMOD						\
		START_SERVERS								\
		STATIC_SOURCE_ENABLE							\
		STATIC_SOURCE_TOUCH_FILE						\
		STORE_METHOD								\
		VCS_TYPE								\

#TODO: ElTexto compatibility only
REWRITE +=										\
		COMMENTS_ON_PAGE							\
		ELTEXTO_VERSION								\
		MEMCACHED_EXPIRE							\
		SYNC_WITH_GROUPS							\
		TEXTS_ON_PAGE								\
		TEXT_IDS_IN_CACHE							\

#TODO: Rate compatibility only
REWRITE +=										\
		RATE_CLASSES								\
		RATE_COOKIE								\

#TODO: Search plugin compatibility only
REWRITE +=                                                                              \
		SEARCH_SERVER                                                           \

#TODO: Util Proxy image 
REWRITE += \
		PROXY_IMAGE_LOCATION \
		PROXY_IMAGE_SECRET \

