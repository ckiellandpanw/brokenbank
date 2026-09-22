#!/bin/sh
# SPDX-FileCopyrightText: GoCortexIO
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# JVM options for Tomcat, sourced automatically by catalina.sh at startup.
#
# com.sun.jndi.ldap.object.trustSerialData gates javaSerializedData
# deserialisation in the LDAP JNDI provider; its default flipped from true
# to false starting at JDK 17.0.13. Confirmed live against this image: with
# it true, log4j-core 2.14.1's own JndiManager.lookup() does deserialise a
# delivered org.apache.naming.ResourceRef correctly, but does not itself
# invoke NamingManager.getObjectInstance() on the result - it returns the
# raw Reference, never handing it to the named factory (BeanFactory). That
# makes the local-gadget (BeanFactory + javaSerializedData) delivery style
# unable to achieve automatic execution through the real log4j lookup path
# on this build, regardless of this flag; it remains set because it is a
# genuine, confirmed prerequisite for that delivery style's deserialisation
# step, and because a fresh JndiManager instance does not reliably observe
# this property if set only at runtime after the JVM has already started -
# it must be present before the JVM boots either way.
#
# com.sun.jndi.ldap.object.trustURLCodebase gates the classic remote-codebase
# Reference technique (javaFactory + javaCodeBase fetching an attacker-hosted
# class over HTTP) - the original, historically-dominant CVE-2021-44228
# mechanism, and NOT the same code path as trustSerialData above. Confirmed
# live against this image, through the real unassisted log4j lookup path (not
# forced/manual resolution): with this true, a remote-codebase Reference
# delivered over LDAP is fetched, loaded and executed automatically by the
# real logger.error() call in Log4ShellServlet, producing a genuine RCE
# callback. This is the delivery style the BBCHAIN-06 deimos campaign's
# Log4Shell stage relies on; trustSerialData above stays set for the
# local-gadget deserialisation step even though that style cannot complete
# automatic resolution on this log4j-core build, so it remains a manual/forced
# demonstration only.
CATALINA_OPTS="$CATALINA_OPTS -Dcom.sun.jndi.ldap.object.trustSerialData=true -Dcom.sun.jndi.ldap.object.trustURLCodebase=true"
export CATALINA_OPTS
