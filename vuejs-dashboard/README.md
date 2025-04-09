# vuejs-dashboard
#
runs the new dashboard inside a container with apache and php
##to build a fresh image
./1.create_image.sh

##to create a container from that built image
./2.create_container.sh

##to start the container the last step built
./3.start_container.sh

##if you need to stop the container
./4.stop_container.sh


##ports used (exposed)
8088 for apache

- no ssl setup at the moment, as its probably not needed (we plan to setup a proxy off the master nginx on aap)

##apache stuff
- the httpd.conf is copied from the apache/httpd/conf/httpd.conf file, to make it easy to secure/change it.

##website stuff
- the website uses php and sqlite as a replacement for mysql.
- the 1.create_image will rebuild the website, but when built, the actual static contents are put into the "publichtml" dir.
- the publichtml dir is included into the image
- playbooks should post to the php pages like this

ansible.builtin.uri:
  url: "http://localhost:8088/post/store_system_status_sqlite.php"

- note the 8088 port. this will keep plays locally posting, and not dependant on an upstream nginx proxy

## image stuff
- the image is based on registry.redhat.io/ubi9/ubi-init:9.5 or registry.redhat.io/ubi9/ubi:9.5
- that image is fully support redhat container image and secure.
- the contents of everything added to that image is inside the "Dockerfile-freshbuild" file. if it needs updating or changed, do it there, and run the 1-4 build steps (hint, for updates)
- while im not a fan of a ton of proxies, that is how aap works. one nginx master, farms requests off based on url to many other nginx servers. we will just do like they do with this.
