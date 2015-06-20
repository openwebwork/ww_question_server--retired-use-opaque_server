Configuration and install instructions:

The standard location for webwork directories are at `/opt/webwork`.  Adjustments
to these instructions need to be made if that is not the case.

`cd /opt/webwork`
`git clone https://github.com/mgage/opaque_server.git`


Copy `conf/opaqueserver.apache-conf.dist` to  `conf/opaqueserver.apache-conf`



If WeBWorK is set up in the standard way with directories 
`/opt/webwork/webwork2` and `/opt/webwor/pg` then the paths to those 
directories do not need to be changed. Otherwise adjustments may be needed
in `opaqueserver.apache-conf`.

Add the line 

`Include /opt/webwork/ww_opaque_server/conf/opaqueserver.apache-config`

to the end of the file `/opt/webwork/webwork2/conf/webwork.apache2.4-config`
(or to `webwork.apache2-config` for  installations using apache2 but not apache2.4)

This code repos will soon be moved to the github.com/openwebwork site. For now 
raise issues at https://github.com/mgage.