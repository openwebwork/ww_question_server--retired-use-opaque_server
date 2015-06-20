Configuration and install instructions:

The standard location for webwork directories are at `/opt/webwork`.  Adjustments
to these instructions need to be made if that is not true in your case.

1. `cd /opt/webwork`   
1. `git clone https://github.com/openwebwork/opaque_server.git`  

1. Copy `conf/opaqueserver.apache-conf.dist` to  `conf/opaqueserver.apache-conf`  

1. Add the line   
`Include /opt/webwork/ww_opaque_server/conf/opaqueserver.apache-config`
to the end of the file `/opt/webwork/webwork2/conf/webwork.apache2.4-config`
(or to `webwork.apache2-config`  for  installations using `apache2` but not `apache2.4`)
1. Restart the apache server (after modifying `opaqueserver.apache-conf` if needed).

If WeBWorK is set up in the standard way with directories 
`/opt/webwork/webwork2` and `/opt/webwork/pg` then the paths to those 
directories do not need to be changed. Otherwise adjustments may be needed
in `opaqueserver.apache-conf`.


The main code repo for opaque_server 
has moved to the `github.com/openwebwork` 
site from `github.com/mgage`. 