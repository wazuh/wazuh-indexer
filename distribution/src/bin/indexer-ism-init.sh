#!/bin/bash
# Wazuh Copyright (C) 2023 Wazuh Inc. (License GPLv2)
# Wazuh - Indexer set rollover policy and templates

# Policy settings
MIN_SHARD_SIZE="25"
MIN_INDEX_AGE="7d"
MIN_DOC_COUNT="600000000"
ISM_INDEX_PATTERNS='["wazuh-alerts-*", "wazuh-archives-*", "-wazuh-alerts-4.x-sample*"]'
ISM_PRIORITY="50"
INDEXER_PASSWORD="admin"
INDEXER_HOSTNAME="localhost"

POLICY_NAME="rollover_policy"
LOG_FILE="/var/log/wazuh-indexer/ism-init.log"

INDEXER_URL="https://${INDEXER_HOSTNAME}:9200"

# curl settings shortcuts
C_AUTH="-u admin:${INDEXER_PASSWORD}"

#########################################################################
# Creates the rollover_policy ISM policy.
# Globals:
#   MIN_SHARD_SIZE: The minimum shard size in GB.
#   MIN_INDEX_AGE: The minimum index age.
#   MIN_DOC_COUNT: The minimum document count.
#   ISM_INDEX_PATTERNS: The index patterns to apply the policy.
#   ISM_PRIORITY: The policy priority.
# Arguments:
#   None.
# Returns:
#   The rollover policy as a JSON string
#########################################################################
function generate_rollover_policy() {
    cat <<-EOF
        {
            "policy": {
                "description": "Wazuh rollover and alias policy",
                "default_state": "active",
                "states": [
                    {
                        "name": "active",
                        "actions": [
                            {
                                "rollover": {
                                    "min_primary_shard_size": "${MIN_SHARD_SIZE}gb",
                                    "min_index_age": "${MIN_INDEX_AGE}",
                                    "min_doc_count": "${MIN_DOC_COUNT}"
                                }
                            }
                        ]
                    }
                ],
                "ism_template": {
                    "index_patterns": ${ISM_INDEX_PATTERNS},
                    "priority": "${ISM_PRIORITY}"
                }
            }
        }
	EOF
}

function generate_common_template() {
    cat <<-EOF
    {
        "template": {
            "settings": {
                "index.refresh_interval": "5s",
                "index.number_of_shards": "3",
                "index.number_of_replicas": "0",
                "index.auto_expand_replicas": "0-1",
                "index.mapping.total_fields.limit": 10000,
                "index.query.default_field": [
                    "GeoLocation.city_name",
                    "GeoLocation.continent_code",
                    "GeoLocation.country_code2",
                    "GeoLocation.country_code3",
                    "GeoLocation.country_name",
                    "GeoLocation.ip",
                    "GeoLocation.postal_code",
                    "GeoLocation.real_region_name",
                    "GeoLocation.region_name",
                    "GeoLocation.timezone",
                    "agent.id",
                    "agent.ip",
                    "agent.name",
                    "cluster.name",
                    "cluster.node",
                    "command",
                    "data",
                    "data.action",
                    "data.audit",
                    "data.audit.acct",
                    "data.audit.arch",
                    "data.audit.auid",
                    "data.audit.command",
                    "data.audit.cwd",
                    "data.audit.dev",
                    "data.audit.directory.inode",
                    "data.audit.directory.mode",
                    "data.audit.directory.name",
                    "data.audit.egid",
                    "data.audit.enforcing",
                    "data.audit.euid",
                    "data.audit.exe",
                    "data.audit.execve.a0",
                    "data.audit.execve.a1",
                    "data.audit.execve.a2",
                    "data.audit.execve.a3",
                    "data.audit.exit",
                    "data.audit.file.inode",
                    "data.audit.file.mode",
                    "data.audit.file.name",
                    "data.audit.fsgid",
                    "data.audit.fsuid",
                    "data.audit.gid",
                    "data.audit.id",
                    "data.audit.key",
                    "data.audit.list",
                    "data.audit.old-auid",
                    "data.audit.old-ses",
                    "data.audit.old_enforcing",
                    "data.audit.old_prom",
                    "data.audit.op",
                    "data.audit.pid",
                    "data.audit.ppid",
                    "data.audit.prom",
                    "data.audit.res",
                    "data.audit.session",
                    "data.audit.sgid",
                    "data.audit.srcip",
                    "data.audit.subj",
                    "data.audit.success",
                    "data.audit.suid",
                    "data.audit.syscall",
                    "data.audit.tty",
                    "data.audit.uid",
                    "data.aws.accountId",
                    "data.aws.account_id",
                    "data.aws.action",
                    "data.aws.actor",
                    "data.aws.aws_account_id",
                    "data.aws.description",
                    "data.aws.dstport",
                    "data.aws.errorCode",
                    "data.aws.errorMessage",
                    "data.aws.eventID",
                    "data.aws.eventName",
                    "data.aws.eventSource",
                    "data.aws.eventType",
                    "data.aws.id",
                    "data.aws.name",
                    "data.aws.requestParameters.accessKeyId",
                    "data.aws.requestParameters.bucketName",
                    "data.aws.requestParameters.gatewayId",
                    "data.aws.requestParameters.groupDescription",
                    "data.aws.requestParameters.groupId",
                    "data.aws.requestParameters.groupName",
                    "data.aws.requestParameters.host",
                    "data.aws.requestParameters.hostedZoneId",
                    "data.aws.requestParameters.instanceId",
                    "data.aws.requestParameters.instanceProfileName",
                    "data.aws.requestParameters.loadBalancerName",
                    "data.aws.requestParameters.loadBalancerPorts",
                    "data.aws.requestParameters.masterUserPassword",
                    "data.aws.requestParameters.masterUsername",
                    "data.aws.requestParameters.name",
                    "data.aws.requestParameters.natGatewayId",
                    "data.aws.requestParameters.networkAclId",
                    "data.aws.requestParameters.path",
                    "data.aws.requestParameters.policyName",
                    "data.aws.requestParameters.port",
                    "data.aws.requestParameters.stackId",
                    "data.aws.requestParameters.stackName",
                    "data.aws.requestParameters.subnetId",
                    "data.aws.requestParameters.subnetIds",
                    "data.aws.requestParameters.volumeId",
                    "data.aws.requestParameters.vpcId",
                    "data.aws.resource.accessKeyDetails.accessKeyId",
                    "data.aws.resource.accessKeyDetails.principalId",
                    "data.aws.resource.accessKeyDetails.userName",
                    "data.aws.resource.instanceDetails.instanceId",
                    "data.aws.resource.instanceDetails.instanceState",
                    "data.aws.resource.instanceDetails.networkInterfaces.privateDnsName",
                    "data.aws.resource.instanceDetails.networkInterfaces.publicDnsName",
                    "data.aws.resource.instanceDetails.networkInterfaces.subnetId",
                    "data.aws.resource.instanceDetails.networkInterfaces.vpcId",
                    "data.aws.resource.instanceDetails.tags.value",
                    "data.aws.responseElements.AssociateVpcCidrBlockResponse.vpcId",
                    "data.aws.responseElements.description",
                    "data.aws.responseElements.instanceId",
                    "data.aws.responseElements.instances.instanceId",
                    "data.aws.responseElements.instancesSet.items.instanceId",
                    "data.aws.responseElements.listeners.port",
                    "data.aws.responseElements.loadBalancerName",
                    "data.aws.responseElements.loadBalancers.vpcId",
                    "data.aws.responseElements.loginProfile.userName",
                    "data.aws.responseElements.networkAcl.vpcId",
                    "data.aws.responseElements.ownerId",
                    "data.aws.responseElements.publicIp",
                    "data.aws.responseElements.user.userId",
                    "data.aws.responseElements.user.userName",
                    "data.aws.responseElements.volumeId",
                    "data.aws.service.serviceName",
                    "data.aws.severity",
                    "data.aws.source",
                    "data.aws.sourceIPAddress",
                    "data.aws.srcport",
                    "data.aws.userIdentity.accessKeyId",
                    "data.aws.userIdentity.accountId",
                    "data.aws.userIdentity.userName",
                    "data.aws.vpcEndpointId",
                    "data.command",
                    "data.cis.group",
                    "data.cis.rule_title",
                    "data.data",
                    "data.docker.Actor.Attributes.container",
                    "data.docker.Actor.Attributes.image",
                    "data.docker.Actor.Attributes.name",
                    "data.docker.Actor.ID",
                    "data.docker.id",
                    "data.docker.message",
                    "data.docker.status",
                    "data.dstip",
                    "data.dstport",
                    "data.dstuser",
                    "data.extra_data",
                    "data.gcp.jsonPayload.queryName",
                    "data.gcp.jsonPayload.vmInstanceName",
                    "data.gcp.resource.labels.location",
                    "data.gcp.resource.labels.project_id",
                    "data.gcp.resource.labels.source_type",
                    "data.gcp.resource.type",
                    "data.github.org",
                    "data.github.actor",
                    "data.github.action",
                    "data.github.repo",
                    "data.hardware.serial",
                    "data.id",
                    "data.integration",
                    "data.netinfo.iface.adapter",
                    "data.netinfo.iface.ipv4.address",
                    "data.netinfo.iface.ipv6.address",
                    "data.netinfo.iface.mac",
                    "data.netinfo.iface.name",
                    "data.office365.Actor.ID",
                    "data.office365.UserId",
                    "data.office365.Operation",
                    "data.office365.ClientIP",
                    "data.ms-graph.relationship",
                    "data.ms-graph.classification",
                    "data.ms-graph.detectionSource",
                    "data.ms-graph.determination",
                    "data.ms-graph.remediationStatus",
                    "data.ms-graph.roles",
                    "data.ms-graph.verdict",
                    "data.ms-graph.serviceSource",
                    "data.ms-graph.severity",
                    "data.ms-graph.actorDisplayName",
                    "data.ms-graph.alertWebUrl",
                    "data.ms-graph.assignedTo",
                    "data.ms-graph.category",
                    "data.ms-graph.comments",
                    "data.ms-graph.description",
                    "data.ms-graph.detectorId",
                    "data.ms-graph.evidence._comment",
                    "data.ms-graph.id",
                    "data.ms-graph.incidentId",
                    "data.ms-graph.incidentWebUrl",
                    "data.ms-graph.mitreTechniques",
                    "data.ms-graph.providerAlertId",
                    "data.ms-graph.resource",
                    "data.ms-graph.status",
                    "data.ms-graph.tenantId",
                    "data.ms-graph.threatDisplayName",
                    "data.ms-graph.threatFamilyName",
                    "data.ms-graph.title",
                    "data.ms-graph.appliedConditionalAccessPolicies",
                    "data.os.architecture",
                    "data.os.build",
                    "data.os.codename",
                    "data.os.hostname",
                    "data.os.major",
                    "data.os.minor",
                    "data.os.patch",
                    "data.os.name",
                    "data.os.platform",
                    "data.os.release",
                    "data.os.release_version",
                    "data.os.display_version",
                    "data.os.sysname",
                    "data.os.version",
                    "data.oscap.check.description",
                    "data.oscap.check.id",
                    "data.oscap.check.identifiers",
                    "data.oscap.check.oval.id",
                    "data.oscap.check.rationale",
                    "data.oscap.check.references",
                    "data.oscap.check.result",
                    "data.oscap.check.severity",
                    "data.oscap.check.title",
                    "data.oscap.scan.benchmark.id",
                    "data.oscap.scan.content",
                    "data.oscap.scan.id",
                    "data.oscap.scan.profile.id",
                    "data.oscap.scan.profile.title",
                    "data.osquery.columns.address",
                    "data.osquery.columns.command",
                    "data.osquery.columns.description",
                    "data.osquery.columns.dst_ip",
                    "data.osquery.columns.gid",
                    "data.osquery.columns.hostname",
                    "data.osquery.columns.md5",
                    "data.osquery.columns.path",
                    "data.osquery.columns.sha1",
                    "data.osquery.columns.sha256",
                    "data.osquery.columns.src_ip",
                    "data.osquery.columns.user",
                    "data.osquery.columns.username",
                    "data.osquery.name",
                    "data.osquery.pack",
                    "data.port.process",
                    "data.port.protocol",
                    "data.port.state",
                    "data.process.args",
                    "data.process.cmd",
                    "data.process.egroup",
                    "data.process.euser",
                    "data.process.fgroup",
                    "data.process.name",
                    "data.process.rgroup",
                    "data.process.ruser",
                    "data.process.sgroup",
                    "data.process.state",
                    "data.process.suser",
                    "data.program.architecture",
                    "data.program.description",
                    "data.program.format",
                    "data.program.location",
                    "data.program.multiarch",
                    "data.program.name",
                    "data.program.priority",
                    "data.program.section",
                    "data.program.source",
                    "data.program.vendor",
                    "data.program.version",
                    "data.protocol",
                    "data.pwd",
                    "data.sca",
                    "data.sca.check.compliance.cis",
                    "data.sca.check.compliance.cis_csc",
                    "data.sca.check.compliance.pci_dss",
                    "data.sca.check.compliance.hipaa",
                    "data.sca.check.compliance.nist_800_53",
                    "data.sca.check.description",
                    "data.sca.check.directory",
                    "data.sca.check.file",
                    "data.sca.check.id",
                    "data.sca.check.previous_result",
                    "data.sca.check.process",
                    "data.sca.check.rationale",
                    "data.sca.check.reason",
                    "data.sca.check.references",
                    "data.sca.check.registry",
                    "data.sca.check.remediation",
                    "data.sca.check.result",
                    "data.sca.check.title",
                    "data.sca.description",
                    "data.sca.file",
                    "data.sca.invalid",
                    "data.sca.name",
                    "data.sca.policy",
                    "data.sca.policy_id",
                    "data.sca.scan_id",
                    "data.sca.total_checks",
                    "data.script",
                    "data.src_ip",
                    "data.src_port",
                    "data.srcip",
                    "data.srcport",
                    "data.srcuser",
                    "data.status",
                    "data.system_name",
                    "data.title",
                    "data.tty",
                    "data.uid",
                    "data.url",
                    "data.virustotal.description",
                    "data.virustotal.error",
                    "data.virustotal.found",
                    "data.virustotal.permalink",
                    "data.virustotal.scan_date",
                    "data.virustotal.sha1",
                    "data.virustotal.source.alert_id",
                    "data.virustotal.source.file",
                    "data.virustotal.source.md5",
                    "data.virustotal.source.sha1",
                    "data.vulnerability.cve",
                    "data.vulnerability.cvss.cvss2.base_score",
                    "data.vulnerability.cvss.cvss2.exploitability_score",
                    "data.vulnerability.cvss.cvss2.impact_score",
                    "data.vulnerability.cvss.cvss2.vector.access_complexity",
                    "data.vulnerability.cvss.cvss2.vector.attack_vector",
                    "data.vulnerability.cvss.cvss2.vector.authentication",
                    "data.vulnerability.cvss.cvss2.vector.availability",
                    "data.vulnerability.cvss.cvss2.vector.confidentiality_impact",
                    "data.vulnerability.cvss.cvss2.vector.integrity_impact",
                    "data.vulnerability.cvss.cvss2.vector.privileges_required",
                    "data.vulnerability.cvss.cvss2.vector.scope",
                    "data.vulnerability.cvss.cvss2.vector.user_interaction",
                    "data.vulnerability.cvss.cvss3.base_score",
                    "data.vulnerability.cvss.cvss3.exploitability_score",
                    "data.vulnerability.cvss.cvss3.impact_score",
                    "data.vulnerability.cvss.cvss3.vector.access_complexity",
                    "data.vulnerability.cvss.cvss3.vector.attack_vector",
                    "data.vulnerability.cvss.cvss3.vector.authentication",
                    "data.vulnerability.cvss.cvss3.vector.availability",
                    "data.vulnerability.cvss.cvss3.vector.confidentiality_impact",
                    "data.vulnerability.cvss.cvss3.vector.integrity_impact",
                    "data.vulnerability.cvss.cvss3.vector.privileges_required",
                    "data.vulnerability.cvss.cvss3.vector.scope",
                    "data.vulnerability.cvss.cvss3.vector.user_interaction",
                    "data.vulnerability.cwe_reference",
                    "data.vulnerability.package.source",
                    "data.vulnerability.package.architecture",
                    "data.vulnerability.package.condition",
                    "data.vulnerability.package.generated_cpe",
                    "data.vulnerability.package.name",
                    "data.vulnerability.package.version",
                    "data.vulnerability.rationale",
                    "data.vulnerability.severity",
                    "data.vulnerability.title",
                    "data.vulnerability.assigner",
                    "data.vulnerability.cve_version",
                    "data.win.eventdata.auditPolicyChanges",
                    "data.win.eventdata.auditPolicyChangesId",
                    "data.win.eventdata.binary",
                    "data.win.eventdata.category",
                    "data.win.eventdata.categoryId",
                    "data.win.eventdata.data",
                    "data.win.eventdata.image",
                    "data.win.eventdata.ipAddress",
                    "data.win.eventdata.ipPort",
                    "data.win.eventdata.keyName",
                    "data.win.eventdata.logonGuid",
                    "data.win.eventdata.logonProcessName",
                    "data.win.eventdata.operation",
                    "data.win.eventdata.parentImage",
                    "data.win.eventdata.processId",
                    "data.win.eventdata.processName",
                    "data.win.eventdata.providerName",
                    "data.win.eventdata.returnCode",
                    "data.win.eventdata.service",
                    "data.win.eventdata.status",
                    "data.win.eventdata.subcategory",
                    "data.win.eventdata.subcategoryGuid",
                    "data.win.eventdata.subcategoryId",
                    "data.win.eventdata.subjectDomainName",
                    "data.win.eventdata.subjectLogonId",
                    "data.win.eventdata.subjectUserName",
                    "data.win.eventdata.subjectUserSid",
                    "data.win.eventdata.targetDomainName",
                    "data.win.eventdata.targetLinkedLogonId",
                    "data.win.eventdata.targetLogonId",
                    "data.win.eventdata.targetUserName",
                    "data.win.eventdata.targetUserSid",
                    "data.win.eventdata.workstationName",
                    "data.win.system.channel",
                    "data.win.system.computer",
                    "data.win.system.eventID",
                    "data.win.system.eventRecordID",
                    "data.win.system.eventSourceName",
                    "data.win.system.keywords",
                    "data.win.system.level",
                    "data.win.system.message",
                    "data.win.system.opcode",
                    "data.win.system.processID",
                    "data.win.system.providerGuid",
                    "data.win.system.providerName",
                    "data.win.system.securityUserID",
                    "data.win.system.severityValue",
                    "data.win.system.userID",
                    "decoder.ftscomment",
                    "decoder.name",
                    "decoder.parent",
                    "full_log",
                    "host",
                    "id",
                    "input",
                    "location",
                    "manager.name",
                    "message",
                    "offset",
                    "predecoder.hostname",
                    "predecoder.program_name",
                    "previous_log",
                    "previous_output",
                    "program_name",
                    "rule.cis",
                    "rule.cve",
                    "rule.description",
                    "rule.gdpr",
                    "rule.gpg13",
                    "rule.groups",
                    "rule.id",
                    "rule.info",
                    "rule.mitre.id",
                    "rule.mitre.tactic",
                    "rule.mitre.technique",
                    "rule.pci_dss",
                    "rule.hipaa",
                    "rule.nist_800_53",
                    "syscheck.audit.effective_user.id",
                    "syscheck.audit.effective_user.name",
                    "syscheck.audit.group.id",
                    "syscheck.audit.group.name",
                    "syscheck.audit.login_user.id",
                    "syscheck.audit.login_user.name",
                    "syscheck.audit.process.id",
                    "syscheck.audit.process.name",
                    "syscheck.audit.process.ppid",
                    "syscheck.audit.user.id",
                    "syscheck.audit.user.name",
                    "syscheck.diff",
                    "syscheck.event",
                    "syscheck.gid_after",
                    "syscheck.gid_before",
                    "syscheck.gname_after",
                    "syscheck.gname_before",
                    "syscheck.inode_after",
                    "syscheck.inode_before",
                    "syscheck.md5_after",
                    "syscheck.md5_before",
                    "syscheck.path",
                    "syscheck.mode",
                    "syscheck.perm_after",
                    "syscheck.perm_before",
                    "syscheck.sha1_after",
                    "syscheck.sha1_before",
                    "syscheck.sha256_after",
                    "syscheck.sha256_before",
                    "syscheck.tags",
                    "syscheck.uid_after",
                    "syscheck.uid_before",
                    "syscheck.uname_after",
                    "syscheck.uname_before",
                    "syscheck.arch",
                    "syscheck.value_name",
                    "syscheck.value_type",
                    "syscheck.changed_attributes",
                    "title"
                ]
            },
            "mappings": {
                "dynamic_templates": [
                    {
                        "string_as_keyword": {
                            "mapping": {
                                "type": "keyword"
                            },
                            "match_mapping_type": "string"
                        }
                    }
                ],
                "date_detection": false,
                "properties": {
                    "@timestamp": {
                        "type": "date"
                    },
                    "timestamp": {
                        "type": "date",
                        "format": "date_optional_time||epoch_millis"
                    },
                    "@version": {
                        "type": "text"
                    },
                    "agent": {
                        "properties": {
                            "ip": {
                                "type": "keyword"
                            },
                            "id": {
                                "type": "keyword"
                            },
                            "name": {
                                "type": "keyword"
                            }
                        }
                    },
                    "manager": {
                        "properties": {
                            "name": {
                                "type": "keyword"
                            }
                        }
                    },
                    "cluster": {
                        "properties": {
                            "name": {
                                "type": "keyword"
                            },
                            "node": {
                                "type": "keyword"
                            }
                        }
                    },
                    "full_log": {
                        "type": "text"
                    },
                    "previous_log": {
                        "type": "text"
                    },
                    "GeoLocation": {
                        "properties": {
                            "area_code": {
                                "type": "long"
                            },
                            "city_name": {
                                "type": "keyword"
                            },
                            "continent_code": {
                                "type": "text"
                            },
                            "coordinates": {
                                "type": "double"
                            },
                            "country_code2": {
                                "type": "text"
                            },
                            "country_code3": {
                                "type": "text"
                            },
                            "country_name": {
                                "type": "keyword"
                            },
                            "dma_code": {
                                "type": "long"
                            },
                            "ip": {
                                "type": "keyword"
                            },
                            "latitude": {
                                "type": "double"
                            },
                            "location": {
                                "type": "geo_point"
                            },
                            "longitude": {
                                "type": "double"
                            },
                            "postal_code": {
                                "type": "keyword"
                            },
                            "real_region_name": {
                                "type": "keyword"
                            },
                            "region_name": {
                                "type": "keyword"
                            },
                            "timezone": {
                                "type": "text"
                            }
                        }
                    },
                    "host": {
                        "type": "keyword"
                    },
                    "syscheck": {
                        "properties": {
                            "path": {
                                "type": "keyword"
                            },
                            "hard_links": {
                                "type": "keyword"
                            },
                            "mode": {
                                "type": "keyword"
                            },
                            "sha1_before": {
                                "type": "keyword"
                            },
                            "sha1_after": {
                                "type": "keyword"
                            },
                            "uid_before": {
                                "type": "keyword"
                            },
                            "uid_after": {
                                "type": "keyword"
                            },
                            "gid_before": {
                                "type": "keyword"
                            },
                            "gid_after": {
                                "type": "keyword"
                            },
                            "perm_before": {
                                "type": "keyword"
                            },
                            "perm_after": {
                                "type": "keyword"
                            },
                            "md5_after": {
                                "type": "keyword"
                            },
                            "md5_before": {
                                "type": "keyword"
                            },
                            "gname_after": {
                                "type": "keyword"
                            },
                            "gname_before": {
                                "type": "keyword"
                            },
                            "inode_after": {
                                "type": "keyword"
                            },
                            "inode_before": {
                                "type": "keyword"
                            },
                            "mtime_after": {
                                "type": "date",
                                "format": "date_optional_time"
                            },
                            "mtime_before": {
                                "type": "date",
                                "format": "date_optional_time"
                            },
                            "uname_after": {
                                "type": "keyword"
                            },
                            "uname_before": {
                                "type": "keyword"
                            },
                            "size_before": {
                                "type": "long"
                            },
                            "size_after": {
                                "type": "long"
                            },
                            "diff": {
                                "type": "keyword"
                            },
                            "event": {
                                "type": "keyword"
                            },
                            "audit": {
                                "properties": {
                                    "effective_user": {
                                        "properties": {
                                            "id": {
                                                "type": "keyword"
                                            },
                                            "name": {
                                                "type": "keyword"
                                            }
                                        }
                                    },
                                    "group": {
                                        "properties": {
                                            "id": {
                                                "type": "keyword"
                                            },
                                            "name": {
                                                "type": "keyword"
                                            }
                                        }
                                    },
                                    "login_user": {
                                        "properties": {
                                            "id": {
                                                "type": "keyword"
                                            },
                                            "name": {
                                                "type": "keyword"
                                            }
                                        }
                                    },
                                    "process": {
                                        "properties": {
                                            "id": {
                                                "type": "keyword"
                                            },
                                            "name": {
                                                "type": "keyword"
                                            },
                                            "ppid": {
                                                "type": "keyword"
                                            }
                                        }
                                    },
                                    "user": {
                                        "properties": {
                                            "id": {
                                                "type": "keyword"
                                            },
                                            "name": {
                                                "type": "keyword"
                                            }
                                        }
                                    }
                                }
                            },
                            "sha256_after": {
                                "type": "keyword"
                            },
                            "sha256_before": {
                                "type": "keyword"
                            },
                            "tags": {
                                "type": "keyword"
                            }
                        }
                    },
                    "location": {
                        "type": "keyword"
                    },
                    "message": {
                        "type": "text"
                    },
                    "offset": {
                        "type": "keyword"
                    },
                    "rule": {
                        "properties": {
                            "description": {
                                "type": "keyword"
                            },
                            "groups": {
                                "type": "keyword"
                            },
                            "level": {
                                "type": "long"
                            },
                            "tsc": {
                                "type": "keyword"
                            },
                            "id": {
                                "type": "keyword"
                            },
                            "cve": {
                                "type": "keyword"
                            },
                            "info": {
                                "type": "keyword"
                            },
                            "frequency": {
                                "type": "long"
                            },
                            "firedtimes": {
                                "type": "long"
                            },
                            "cis": {
                                "type": "keyword"
                            },
                            "pci_dss": {
                                "type": "keyword"
                            },
                            "gdpr": {
                                "type": "keyword"
                            },
                            "gpg13": {
                                "type": "keyword"
                            },
                            "hipaa": {
                                "type": "keyword"
                            },
                            "nist_800_53": {
                                "type": "keyword"
                            },
                            "mail": {
                                "type": "boolean"
                            },
                            "mitre": {
                                "properties": {
                                    "id": {
                                        "type": "keyword"
                                    },
                                    "tactic": {
                                        "type": "keyword"
                                    },
                                    "technique": {
                                        "type": "keyword"
                                    }
                                }
                            }
                        }
                    },
                    "predecoder": {
                        "properties": {
                            "program_name": {
                                "type": "keyword"
                            },
                            "timestamp": {
                                "type": "keyword"
                            },
                            "hostname": {
                                "type": "keyword"
                            }
                        }
                    },
                    "decoder": {
                        "properties": {
                            "parent": {
                                "type": "keyword"
                            },
                            "name": {
                                "type": "keyword"
                            },
                            "ftscomment": {
                                "type": "keyword"
                            },
                            "fts": {
                                "type": "long"
                            },
                            "accumulate": {
                                "type": "long"
                            }
                        }
                    },
                    "data": {
                        "properties": {
                            "audit": {
                                "properties": {
                                    "acct": {
                                        "type": "keyword"
                                    },
                                    "arch": {
                                        "type": "keyword"
                                    },
                                    "auid": {
                                        "type": "keyword"
                                    },
                                    "command": {
                                        "type": "keyword"
                                    },
                                    "cwd": {
                                        "type": "keyword"
                                    },
                                    "dev": {
                                        "type": "keyword"
                                    },
                                    "directory": {
                                        "properties": {
                                            "inode": {
                                                "type": "keyword"
                                            },
                                            "mode": {
                                                "type": "keyword"
                                            },
                                            "name": {
                                                "type": "keyword"
                                            }
                                        }
                                    },
                                    "egid": {
                                        "type": "keyword"
                                    },
                                    "enforcing": {
                                        "type": "keyword"
                                    },
                                    "euid": {
                                        "type": "keyword"
                                    },
                                    "exe": {
                                        "type": "keyword"
                                    },
                                    "execve": {
                                        "properties": {
                                            "a0": {
                                                "type": "keyword"
                                            },
                                            "a1": {
                                                "type": "keyword"
                                            },
                                            "a2": {
                                                "type": "keyword"
                                            },
                                            "a3": {
                                                "type": "keyword"
                                            }
                                        }
                                    },
                                    "exit": {
                                        "type": "keyword"
                                    },
                                    "file": {
                                        "properties": {
                                            "inode": {
                                                "type": "keyword"
                                            },
                                            "mode": {
                                                "type": "keyword"
                                            },
                                            "name": {
                                                "type": "keyword"
                                            }
                                        }
                                    },
                                    "fsgid": {
                                        "type": "keyword"
                                    },
                                    "fsuid": {
                                        "type": "keyword"
                                    },
                                    "gid": {
                                        "type": "keyword"
                                    },
                                    "id": {
                                        "type": "keyword"
                                    },
                                    "key": {
                                        "type": "keyword"
                                    },
                                    "list": {
                                        "type": "keyword"
                                    },
                                    "old-auid": {
                                        "type": "keyword"
                                    },
                                    "old-ses": {
                                        "type": "keyword"
                                    },
                                    "old_enforcing": {
                                        "type": "keyword"
                                    },
                                    "old_prom": {
                                        "type": "keyword"
                                    },
                                    "op": {
                                        "type": "keyword"
                                    },
                                    "pid": {
                                        "type": "keyword"
                                    },
                                    "ppid": {
                                        "type": "keyword"
                                    },
                                    "prom": {
                                        "type": "keyword"
                                    },
                                    "res": {
                                        "type": "keyword"
                                    },
                                    "session": {
                                        "type": "keyword"
                                    },
                                    "sgid": {
                                        "type": "keyword"
                                    },
                                    "srcip": {
                                        "type": "keyword"
                                    },
                                    "subj": {
                                        "type": "keyword"
                                    },
                                    "success": {
                                        "type": "keyword"
                                    },
                                    "suid": {
                                        "type": "keyword"
                                    },
                                    "syscall": {
                                        "type": "keyword"
                                    },
                                    "tty": {
                                        "type": "keyword"
                                    },
                                    "type": {
                                        "type": "keyword"
                                    },
                                    "uid": {
                                        "type": "keyword"
                                    }
                                }
                            },
                            "protocol": {
                                "type": "keyword"
                            },
                            "action": {
                                "type": "keyword"
                            },
                            "srcip": {
                                "type": "keyword"
                            },
                            "dstip": {
                                "type": "keyword"
                            },
                            "srcport": {
                                "type": "keyword"
                            },
                            "dstport": {
                                "type": "keyword"
                            },
                            "srcuser": {
                                "type": "keyword"
                            },
                            "dstuser": {
                                "type": "keyword"
                            },
                            "id": {
                                "type": "keyword"
                            },
                            "status": {
                                "type": "keyword"
                            },
                            "data": {
                                "type": "keyword"
                            },
                            "extra_data": {
                                "type": "keyword"
                            },
                            "system_name": {
                                "type": "keyword"
                            },
                            "url": {
                                "type": "keyword"
                            },
                            "oscap": {
                                "properties": {
                                    "check": {
                                        "properties": {
                                            "description": {
                                                "type": "text"
                                            },
                                            "id": {
                                                "type": "keyword"
                                            },
                                            "identifiers": {
                                                "type": "text"
                                            },
                                            "oval": {
                                                "properties": {
                                                    "id": {
                                                        "type": "keyword"
                                                    }
                                                }
                                            },
                                            "rationale": {
                                                "type": "text"
                                            },
                                            "references": {
                                                "type": "text"
                                            },
                                            "result": {
                                                "type": "keyword"
                                            },
                                            "severity": {
                                                "type": "keyword"
                                            },
                                            "title": {
                                                "type": "keyword"
                                            }
                                        }
                                    },
                                    "scan": {
                                        "properties": {
                                            "benchmark": {
                                                "properties": {
                                                    "id": {
                                                        "type": "keyword"
                                                    }
                                                }
                                            },
                                            "content": {
                                                "type": "keyword"
                                            },
                                            "id": {
                                                "type": "keyword"
                                            },
                                            "profile": {
                                                "properties": {
                                                    "id": {
                                                        "type": "keyword"
                                                    },
                                                    "title": {
                                                        "type": "keyword"
                                                    }
                                                }
                                            },
                                            "return_code": {
                                                "type": "long"
                                            },
                                            "score": {
                                                "type": "double"
                                            }
                                        }
                                    }
                                }
                            },
                            "office365": {
                                "properties": {
                                    "Actor": {
                                        "properties": {
                                            "ID": {
                                                "type": "keyword"
                                            }
                                        }
                                    },
                                    "UserId": {
                                        "type": "keyword"
                                    },
                                    "Operation": {
                                        "type": "keyword"
                                    },
                                    "ClientIP": {
                                        "type": "keyword"
                                    },
                                    "ResultStatus": {
                                        "type": "keyword"
                                    },
                                    "Subscription": {
                                        "type": "keyword"
                                    }
                                }
                            },
                            "github": {
                                "properties": {
                                    "org": {
                                        "type": "keyword"
                                    },
                                    "actor": {
                                        "type": "keyword"
                                    },
                                    "action": {
                                        "type": "keyword"
                                    },
                                    "actor_location": {
                                        "properties": {
                                            "country_code": {
                                                "type": "keyword"
                                            }
                                        }
                                    },
                                    "repo": {
                                        "type": "keyword"
                                    }
                                }
                            },
                            "ms-graph": {
                                "properties": {
                                    "relationship": {
                                        "type": "keyword"
                                    },
                                    "classification": {
                                        "type": "keyword"
                                    },
                                    "detectionSource": {
                                        "type": "keyword"
                                    },
                                    "determination": {
                                        "type": "keyword"
                                    },
                                    "remediationStatus": {
                                        "type": "keyword"
                                    },
                                    "roles": {
                                        "type": "keyword"
                                    },
                                    "verdict": {
                                        "type": "keyword"
                                    },
                                    "serviceSource": {
                                        "type": "keyword"
                                    },
                                    "severity": {
                                        "type": "keyword"
                                    },
                                    "actorDisplayName": {
                                        "type": "keyword"
                                    },
                                    "alertWebUrl": {
                                        "type": "keyword"
                                    },
                                    "assignedTo": {
                                        "type": "keyword"
                                    },
                                    "category": {
                                        "type": "keyword"
                                    },
                                    "comments": {
                                        "type": "keyword"
                                    },
                                    "createdDateTime": {
                                        "type": "date"
                                    },
                                    "description": {
                                        "type": "text"
                                    },
                                    "detectorId": {
                                        "type": "keyword"
                                    },
                                    "evidence": {
                                        "type": "nested",
                                        "properties": {
                                            "_comment": {
                                                "type": "keyword"
                                            }
                                        }
                                    },
                                    "firstActivityDateTime": {
                                        "type": "date"
                                    },
                                    "id": {
                                        "type": "keyword"
                                    },
                                    "incidentId": {
                                        "type": "keyword"
                                    },
                                    "incidentWebUrl": {
                                        "type": "keyword"
                                    },
                                    "lastActivityDateTime": {
                                        "type": "date"
                                    },
                                    "lastUpdateDateTime": {
                                        "type": "date"
                                    },
                                    "mitreTechniques": {
                                        "type": "keyword"
                                    },
                                    "providerAlertId": {
                                        "type": "keyword"
                                    },
                                    "resolvedDateTime": {
                                        "type": "date"
                                    },
                                    "resource": {
                                        "type": "keyword"
                                    },
                                    "status": {
                                        "type": "keyword"
                                    },
                                    "tenantId": {
                                        "type": "keyword"
                                    },
                                    "threatDisplayName": {
                                        "type": "keyword"
                                    },
                                    "threatFamilyName": {
                                        "type": "keyword"
                                    },
                                    "title": {
                                        "type": "keyword"
                                    },
                                    "appliedConditionalAccessPolicies": {
                                        "type": "keyword"
                                    }
                                }
                            },
                            "type": {
                                "type": "keyword"
                            },
                            "netinfo": {
                                "properties": {
                                    "iface": {
                                        "properties": {
                                            "name": {
                                                "type": "keyword"
                                            },
                                            "mac": {
                                                "type": "keyword"
                                            },
                                            "adapter": {
                                                "type": "keyword"
                                            },
                                            "type": {
                                                "type": "keyword"
                                            },
                                            "state": {
                                                "type": "keyword"
                                            },
                                            "mtu": {
                                                "type": "long"
                                            },
                                            "tx_bytes": {
                                                "type": "long"
                                            },
                                            "rx_bytes": {
                                                "type": "long"
                                            },
                                            "tx_errors": {
                                                "type": "long"
                                            },
                                            "rx_errors": {
                                                "type": "long"
                                            },
                                            "tx_dropped": {
                                                "type": "long"
                                            },
                                            "rx_dropped": {
                                                "type": "long"
                                            },
                                            "tx_packets": {
                                                "type": "long"
                                            },
                                            "rx_packets": {
                                                "type": "long"
                                            },
                                            "ipv4": {
                                                "properties": {
                                                    "gateway": {
                                                        "type": "keyword"
                                                    },
                                                    "dhcp": {
                                                        "type": "keyword"
                                                    },
                                                    "address": {
                                                        "type": "keyword"
                                                    },
                                                    "netmask": {
                                                        "type": "keyword"
                                                    },
                                                    "broadcast": {
                                                        "type": "keyword"
                                                    },
                                                    "metric": {
                                                        "type": "long"
                                                    }
                                                }
                                            },
                                            "ipv6": {
                                                "properties": {
                                                    "gateway": {
                                                        "type": "keyword"
                                                    },
                                                    "dhcp": {
                                                        "type": "keyword"
                                                    },
                                                    "address": {
                                                        "type": "keyword"
                                                    },
                                                    "netmask": {
                                                        "type": "keyword"
                                                    },
                                                    "broadcast": {
                                                        "type": "keyword"
                                                    },
                                                    "metric": {
                                                        "type": "long"
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            },
                            "os": {
                                "properties": {
                                    "hostname": {
                                        "type": "keyword"
                                    },
                                    "architecture": {
                                        "type": "keyword"
                                    },
                                    "name": {
                                        "type": "keyword"
                                    },
                                    "version": {
                                        "type": "keyword"
                                    },
                                    "codename": {
                                        "type": "keyword"
                                    },
                                    "major": {
                                        "type": "keyword"
                                    },
                                    "minor": {
                                        "type": "keyword"
                                    },
                                    "patch": {
                                        "type": "keyword"
                                    },
                                    "build": {
                                        "type": "keyword"
                                    },
                                    "platform": {
                                        "type": "keyword"
                                    },
                                    "sysname": {
                                        "type": "keyword"
                                    },
                                    "release": {
                                        "type": "keyword"
                                    },
                                    "release_version": {
                                        "type": "keyword"
                                    },
                                    "display_version": {
                                        "type": "keyword"
                                    }
                                }
                            },
                            "port": {
                                "properties": {
                                    "protocol": {
                                        "type": "keyword"
                                    },
                                    "local_ip": {
                                        "type": "ip"
                                    },
                                    "local_port": {
                                        "type": "long"
                                    },
                                    "remote_ip": {
                                        "type": "ip"
                                    },
                                    "remote_port": {
                                        "type": "long"
                                    },
                                    "tx_queue": {
                                        "type": "long"
                                    },
                                    "rx_queue": {
                                        "type": "long"
                                    },
                                    "inode": {
                                        "type": "long"
                                    },
                                    "state": {
                                        "type": "keyword"
                                    },
                                    "pid": {
                                        "type": "long"
                                    },
                                    "process": {
                                        "type": "keyword"
                                    }
                                }
                            },
                            "hardware": {
                                "properties": {
                                    "serial": {
                                        "type": "keyword"
                                    },
                                    "cpu_name": {
                                        "type": "keyword"
                                    },
                                    "cpu_cores": {
                                        "type": "long"
                                    },
                                    "cpu_mhz": {
                                        "type": "double"
                                    },
                                    "ram_total": {
                                        "type": "long"
                                    },
                                    "ram_free": {
                                        "type": "long"
                                    },
                                    "ram_usage": {
                                        "type": "long"
                                    }
                                }
                            },
                            "program": {
                                "properties": {
                                    "format": {
                                        "type": "keyword"
                                    },
                                    "name": {
                                        "type": "keyword"
                                    },
                                    "priority": {
                                        "type": "keyword"
                                    },
                                    "section": {
                                        "type": "keyword"
                                    },
                                    "size": {
                                        "type": "long"
                                    },
                                    "vendor": {
                                        "type": "keyword"
                                    },
                                    "install_time": {
                                        "type": "keyword"
                                    },
                                    "version": {
                                        "type": "keyword"
                                    },
                                    "architecture": {
                                        "type": "keyword"
                                    },
                                    "multiarch": {
                                        "type": "keyword"
                                    },
                                    "source": {
                                        "type": "keyword"
                                    },
                                    "description": {
                                        "type": "keyword"
                                    },
                                    "location": {
                                        "type": "keyword"
                                    }
                                }
                            },
                            "process": {
                                "properties": {
                                    "pid": {
                                        "type": "long"
                                    },
                                    "name": {
                                        "type": "keyword"
                                    },
                                    "state": {
                                        "type": "keyword"
                                    },
                                    "ppid": {
                                        "type": "long"
                                    },
                                    "utime": {
                                        "type": "long"
                                    },
                                    "stime": {
                                        "type": "long"
                                    },
                                    "cmd": {
                                        "type": "keyword"
                                    },
                                    "args": {
                                        "type": "keyword"
                                    },
                                    "euser": {
                                        "type": "keyword"
                                    },
                                    "ruser": {
                                        "type": "keyword"
                                    },
                                    "suser": {
                                        "type": "keyword"
                                    },
                                    "egroup": {
                                        "type": "keyword"
                                    },
                                    "sgroup": {
                                        "type": "keyword"
                                    },
                                    "fgroup": {
                                        "type": "keyword"
                                    },
                                    "rgroup": {
                                        "type": "keyword"
                                    },
                                    "priority": {
                                        "type": "long"
                                    },
                                    "nice": {
                                        "type": "long"
                                    },
                                    "size": {
                                        "type": "long"
                                    },
                                    "vm_size": {
                                        "type": "long"
                                    },
                                    "resident": {
                                        "type": "long"
                                    },
                                    "share": {
                                        "type": "long"
                                    },
                                    "start_time": {
                                        "type": "long"
                                    },
                                    "pgrp": {
                                        "type": "long"
                                    },
                                    "session": {
                                        "type": "long"
                                    },
                                    "nlwp": {
                                        "type": "long"
                                    },
                                    "tgid": {
                                        "type": "long"
                                    },
                                    "tty": {
                                        "type": "long"
                                    },
                                    "processor": {
                                        "type": "long"
                                    }
                                }
                            },
                            "sca": {
                                "properties": {
                                    "type": {
                                        "type": "keyword"
                                    },
                                    "scan_id": {
                                        "type": "keyword"
                                    },
                                    "policy": {
                                        "type": "keyword"
                                    },
                                    "name": {
                                        "type": "keyword"
                                    },
                                    "file": {
                                        "type": "keyword"
                                    },
                                    "description": {
                                        "type": "keyword"
                                    },
                                    "passed": {
                                        "type": "integer"
                                    },
                                    "failed": {
                                        "type": "integer"
                                    },
                                    "score": {
                                        "type": "long"
                                    },
                                    "check": {
                                        "properties": {
                                            "id": {
                                                "type": "keyword"
                                            },
                                            "title": {
                                                "type": "keyword"
                                            },
                                            "description": {
                                                "type": "keyword"
                                            },
                                            "rationale": {
                                                "type": "keyword"
                                            },
                                            "remediation": {
                                                "type": "keyword"
                                            },
                                            "compliance": {
                                                "properties": {
                                                    "cis": {
                                                        "type": "keyword"
                                                    },
                                                    "cis_csc": {
                                                        "type": "keyword"
                                                    },
                                                    "pci_dss": {
                                                        "type": "keyword"
                                                    },
                                                    "hipaa": {
                                                        "type": "keyword"
                                                    },
                                                    "nist_800_53": {
                                                        "type": "keyword"
                                                    }
                                                }
                                            },
                                            "references": {
                                                "type": "keyword"
                                            },
                                            "file": {
                                                "type": "keyword"
                                            },
                                            "directory": {
                                                "type": "keyword"
                                            },
                                            "registry": {
                                                "type": "keyword"
                                            },
                                            "process": {
                                                "type": "keyword"
                                            },
                                            "result": {
                                                "type": "keyword"
                                            },
                                            "previous_result": {
                                                "type": "keyword"
                                            },
                                            "reason": {
                                                "type": "keyword"
                                            }
                                        }
                                    },
                                    "invalid": {
                                        "type": "keyword"
                                    },
                                    "policy_id": {
                                        "type": "keyword"
                                    },
                                    "total_checks": {
                                        "type": "keyword"
                                    }
                                }
                            },
                            "command": {
                                "type": "keyword"
                            },
                            "integration": {
                                "type": "keyword"
                            },
                            "timestamp": {
                                "type": "date"
                            },
                            "title": {
                                "type": "keyword"
                            },
                            "uid": {
                                "type": "keyword"
                            },
                            "virustotal": {
                                "properties": {
                                    "description": {
                                        "type": "keyword"
                                    },
                                    "error": {
                                        "type": "keyword"
                                    },
                                    "found": {
                                        "type": "keyword"
                                    },
                                    "malicious": {
                                        "type": "keyword"
                                    },
                                    "permalink": {
                                        "type": "keyword"
                                    },
                                    "positives": {
                                        "type": "keyword"
                                    },
                                    "scan_date": {
                                        "type": "keyword"
                                    },
                                    "sha1": {
                                        "type": "keyword"
                                    },
                                    "source": {
                                        "properties": {
                                            "alert_id": {
                                                "type": "keyword"
                                            },
                                            "file": {
                                                "type": "keyword"
                                            },
                                            "md5": {
                                                "type": "keyword"
                                            },
                                            "sha1": {
                                                "type": "keyword"
                                            }
                                        }
                                    },
                                    "total": {
                                        "type": "keyword"
                                    }
                                }
                            },
                            "vulnerability": {
                                "properties": {
                                    "cve": {
                                        "type": "keyword"
                                    },
                                    "cvss": {
                                        "properties": {
                                            "cvss2": {
                                                "properties": {
                                                    "base_score": {
                                                        "type": "keyword"
                                                    },
                                                    "exploitability_score": {
                                                        "type": "keyword"
                                                    },
                                                    "impact_score": {
                                                        "type": "keyword"
                                                    },
                                                    "vector": {
                                                        "properties": {
                                                            "access_complexity": {
                                                                "type": "keyword"
                                                            },
                                                            "attack_vector": {
                                                                "type": "keyword"
                                                            },
                                                            "authentication": {
                                                                "type": "keyword"
                                                            },
                                                            "availability": {
                                                                "type": "keyword"
                                                            },
                                                            "confidentiality_impact": {
                                                                "type": "keyword"
                                                            },
                                                            "integrity_impact": {
                                                                "type": "keyword"
                                                            },
                                                            "privileges_required": {
                                                                "type": "keyword"
                                                            },
                                                            "scope": {
                                                                "type": "keyword"
                                                            },
                                                            "user_interaction": {
                                                                "type": "keyword"
                                                            }
                                                        }
                                                    }
                                                }
                                            },
                                            "cvss3": {
                                                "properties": {
                                                    "base_score": {
                                                        "type": "keyword"
                                                    },
                                                    "exploitability_score": {
                                                        "type": "keyword"
                                                    },
                                                    "impact_score": {
                                                        "type": "keyword"
                                                    },
                                                    "vector": {
                                                        "properties": {
                                                            "access_complexity": {
                                                                "type": "keyword"
                                                            },
                                                            "attack_vector": {
                                                                "type": "keyword"
                                                            },
                                                            "authentication": {
                                                                "type": "keyword"
                                                            },
                                                            "availability": {
                                                                "type": "keyword"
                                                            },
                                                            "confidentiality_impact": {
                                                                "type": "keyword"
                                                            },
                                                            "integrity_impact": {
                                                                "type": "keyword"
                                                            },
                                                            "privileges_required": {
                                                                "type": "keyword"
                                                            },
                                                            "scope": {
                                                                "type": "keyword"
                                                            },
                                                            "user_interaction": {
                                                                "type": "keyword"
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    },
                                    "cwe_reference": {
                                        "type": "keyword"
                                    },
                                    "package": {
                                        "properties": {
                                            "source": {
                                                "type": "keyword"
                                            },
                                            "architecture": {
                                                "type": "keyword"
                                            },
                                            "condition": {
                                                "type": "keyword"
                                            },
                                            "generated_cpe": {
                                                "type": "keyword"
                                            },
                                            "name": {
                                                "type": "keyword"
                                            },
                                            "version": {
                                                "type": "keyword"
                                            }
                                        }
                                    },
                                    "published": {
                                        "type": "date"
                                    },
                                    "updated": {
                                        "type": "date"
                                    },
                                    "rationale": {
                                        "type": "keyword"
                                    },
                                    "severity": {
                                        "type": "keyword"
                                    },
                                    "title": {
                                        "type": "keyword"
                                    },
                                    "assigner": {
                                        "type": "keyword"
                                    },
                                    "cve_version": {
                                        "type": "keyword"
                                    }
                                }
                            },
                            "aws": {
                                "properties": {
                                    "source": {
                                        "type": "keyword"
                                    },
                                    "accountId": {
                                        "type": "keyword"
                                    },
                                    "log_info": {
                                        "properties": {
                                            "s3bucket": {
                                                "type": "keyword"
                                            }
                                        }
                                    },
                                    "region": {
                                        "type": "keyword"
                                    },
                                    "bytes": {
                                        "type": "long"
                                    },
                                    "dstaddr": {
                                        "type": "ip"
                                    },
                                    "srcaddr": {
                                        "type": "ip"
                                    },
                                    "end": {
                                        "type": "date"
                                    },
                                    "start": {
                                        "type": "date"
                                    },
                                    "source_ip_address": {
                                        "type": "ip"
                                    },
                                    "service": {
                                        "properties": {
                                            "count": {
                                                "type": "long"
                                            },
                                            "action.networkConnectionAction.remoteIpDetails": {
                                                "properties": {
                                                    "ipAddressV4": {
                                                        "type": "ip"
                                                    },
                                                    "geoLocation": {
                                                        "type": "geo_point"
                                                    }
                                                }
                                            },
                                            "eventFirstSeen": {
                                                "type": "date"
                                            },
                                            "eventLastSeen": {
                                                "type": "date"
                                            }
                                        }
                                    },
                                    "createdAt": {
                                        "type": "date"
                                    },
                                    "updatedAt": {
                                        "type": "date"
                                    },
                                    "resource.instanceDetails": {
                                        "properties": {
                                            "launchTime": {
                                                "type": "date"
                                            },
                                            "networkInterfaces": {
                                                "properties": {
                                                    "privateIpAddress": {
                                                        "type": "ip"
                                                    },
                                                    "publicIp": {
                                                        "type": "ip"
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            },
                            "cis": {
                                "properties": {
                                    "benchmark": {
                                        "type": "keyword"
                                    },
                                    "error": {
                                        "type": "long"
                                    },
                                    "fail": {
                                        "type": "long"
                                    },
                                    "group": {
                                        "type": "keyword"
                                    },
                                    "notchecked": {
                                        "type": "long"
                                    },
                                    "pass": {
                                        "type": "long"
                                    },
                                    "result": {
                                        "type": "keyword"
                                    },
                                    "rule_title": {
                                        "type": "keyword"
                                    },
                                    "score": {
                                        "type": "long"
                                    },
                                    "timestamp": {
                                        "type": "keyword"
                                    },
                                    "unknown": {
                                        "type": "long"
                                    }
                                }
                            },
                            "docker": {
                                "properties": {
                                    "Action": {
                                        "type": "keyword"
                                    },
                                    "Actor": {
                                        "properties": {
                                            "Attributes": {
                                                "properties": {
                                                    "image": {
                                                        "type": "keyword"
                                                    },
                                                    "name": {
                                                        "type": "keyword"
                                                    }
                                                }
                                            }
                                        }
                                    },
                                    "Type": {
                                        "type": "keyword"
                                    }
                                }
                            },
                            "gcp": {
                                "properties": {
                                    "jsonPayload": {
                                        "properties": {
                                            "authAnswer": {
                                                "type": "keyword"
                                            },
                                            "queryName": {
                                                "type": "keyword"
                                            },
                                            "responseCode": {
                                                "type": "keyword"
                                            },
                                            "vmInstanceId": {
                                                "type": "keyword"
                                            },
                                            "vmInstanceName": {
                                                "type": "keyword"
                                            }
                                        }
                                    },
                                    "resource": {
                                        "properties": {
                                            "labels": {
                                                "properties": {
                                                    "location": {
                                                        "type": "keyword"
                                                    },
                                                    "project_id": {
                                                        "type": "keyword"
                                                    },
                                                    "source_type": {
                                                        "type": "keyword"
                                                    }
                                                }
                                            },
                                            "type": {
                                                "type": "keyword"
                                            }
                                        }
                                    },
                                    "severity": {
                                        "type": "keyword"
                                    }
                                }
                            },
                            "osquery": {
                                "properties": {
                                    "name": {
                                        "type": "keyword"
                                    },
                                    "pack": {
                                        "type": "keyword"
                                    },
                                    "action": {
                                        "type": "keyword"
                                    },
                                    "calendarTime": {
                                        "type": "keyword"
                                    }
                                }
                            },
                            "parameters": {
                                "properties": {
                                    "extra_args": {
                                        "type": "keyword"
                                    }
                                }
                            }
                        }
                    },
                    "program_name": {
                        "type": "keyword"
                    },
                    "command": {
                        "type": "keyword"
                    },
                    "type": {
                        "type": "text"
                    },
                    "title": {
                        "type": "keyword"
                    },
                    "id": {
                        "type": "keyword"
                    },
                    "input": {
                        "properties": {
                            "type": {
                                "type": "keyword"
                            }
                        }
                    },
                    "previous_output": {
                        "type": "keyword"
                    }
                }
            }
        }
    }
	EOF
}

#########################################################################
# Generates the component templates.
# Arguments:
#   - The alias name, a string.
# Returns:
#   The component template as a JSON string.
#########################################################################
function generate_component_template() {
    if [ "${1}" == "common" ]; then
        generate_common_template
    else
        cat <<-EOF
        {
            "template": {
                "aliases": {
                    "${1}": {
                        "is_write_index": true
                    }
                },
                "settings": {
                    "index": {
                        "plugins": {
                            "index_state_management": {
                                "rollover_alias": "${1}"
                            }
                        }
                    }
                }
            }
        }
		EOF
    fi
}

#########################################################################
# Generates the index templates.
# Arguments:
#   - The index name, a string. Also used as index pattern.
# Returns:
#   The index template as a JSON string.
#########################################################################
function generate_index_template() {
    cat <<-EOF
    {
        "priority": 3,
        "index_patterns": [
            "${1}-*"
        ],
        "composed_of": [
            "common",
            "${1}"
        ],
        "version": 3,
        "_meta": {
            "description": "${1} index template using component templates"
        }
    }
	EOF
}

#########################################################################
# Uploads index or component templates to the indexer.
#########################################################################
function upload_template() {
    "generate_${2}_template" "${1}" |
    if ! curl -s -k ${C_AUTH} \
        -X PUT "${INDEXER_URL}/_${2}_template/${1}" \
        -o "${LOG_FILE}" --create-dirs \
        -H 'Content-Type: application/json' -d @-; then
        echo "  ERROR: '${1}' ${2} template creation failed"
        return 1
    else
        echo " SUCC: '${1}' ${2} template created or updated"
    fi
}

#########################################################################
# Loads the index templates for the rollover policy to the indexer.
#########################################################################
function load_templates() {
    # Note: the wazuh-template.json could also be loaded here.
    local templates=("${aliases[@]}" "common")

    echo "Will create component templates to configure the alias"
    for i in "${templates[@]}"; do
        upload_template "${i}" "component"
    done
    echo "Will create composable index templates"
    for i in "${aliases[@]}"; do
        upload_template "${i}" "index"
    done
}

#########################################################################
# Uploads the rollover policy.
#   If the policy does not exist, the policy "${POLICY_NAME}" is created.
#   If the policy exists, but the rollover conditions are different, the
#   policy is updated.
# Arguments:
#   None.
#########################################################################
function upload_rollover_policy() {
    echo "Will create the '${POLICY_NAME}' policy"
    policy_exists=$(
        curl -s -k ${C_AUTH} \
            -X GET "${INDEXER_URL}/_plugins/_ism/policies/${POLICY_NAME}" \
            -o "${LOG_FILE}" --create-dirs \
            -w "%{http_code}"
    )

    # Check if the ${POLICY_NAME} ISM policy was loaded (404 error if not found)
    if [[ "${policy_exists}" == "404" ]]; then
        policy_uploaded=$(
            curl -s -k ${C_AUTH} \
                -X PUT "${INDEXER_URL}/_plugins/_ism/policies/${POLICY_NAME}" \
                -o "${LOG_FILE}" --create-dirs \
                -H 'Content-Type: application/json' \
                -d "$(generate_rollover_policy)" \
                -w "%{http_code}"
        )

        if [[ "${policy_uploaded}" == "201" ]]; then
            echo "  SUCC: '${POLICY_NAME}' policy created"
        else
            echo "  ERROR: '${POLICY_NAME}' policy not created => ${policy_uploaded}"
            return 1
        fi
    else
        if [[ "${policy_exists}" == "200" ]]; then
            echo "  INFO: policy '${POLICY_NAME}' already exists. Skipping policy creation"
        else
            echo "  ERROR: could not check if the policy '${POLICY_NAME}' exists => ${policy_exists}"
            return 1
        fi
    fi
}

#########################################################################
# Check if an alias exists in the indexer.
# Arguments:
#   1. The alias to look for. String.
#########################################################################
function check_for_write_index() {
    curl -s -k ${C_AUTH} "${INDEXER_URL}/_cat/aliases" |
        grep -i "${1}" |
        grep -i true |
        awk '{print $2}'
}

#########################################################################
# Creates the initial aliased write index.
# Arguments:
#   1. The alias. String.
#########################################################################
function create_write_index() {
    if ! curl -s -k ${C_AUTH} -o "${LOG_FILE}" --create-dirs \
        -X PUT "$INDEXER_URL/%3C${1}-4.x-%7Bnow%2Fd%7D-000001%3E" \
        -H 'Content-Type: application/json'
    then
        echo "  ERROR: creating '${1}' write index"
        exit 1
    else
        echo "  SUCC: '${1}' write index created"
    fi
}

#########################################################################
# Creates the write indices for the aliases given as parameter.
# Arguments:
#   1. List of aliases to initialize.
#########################################################################
function create_indices() {
    echo "Will create initial indices for the aliases"
    for alias in "${aliases[@]}"; do
        # Check if there are any write indices for the current alias
        write_index_exists=$(check_for_write_index "${alias}")

        # Create the write index if it does not exist
        if [[ -z $write_index_exists ]]; then
            create_write_index "${alias}"
        else
            echo "  INFO: '${alias}' write index already exists. Skipping write index creation"
        fi
    done
}

#########################################################################
# Shows usage help.
#########################################################################
function show_help() {
    echo -e ""
    echo -e "NAME"
    echo -e "        indexer-ism-init.sh - Manages the Index State Management plugin for Wazuh indexer index rollovers policies."
    echo -e ""
    echo -e "SYNOPSIS"
    echo -e "        indexer-ism-init.sh [OPTIONS]"
    echo -e ""
    echo -e "DESCRIPTION"
    echo -e "        -a,  --min-index-age <index-age>"
    echo -e "                Set the minimum index age. By default 7d."
    echo -e ""
    echo -e "        -d, --min-doc-count <doc-count>"
    echo -e "                Set the minimum document count. By default 200000000."
    echo -e ""
    echo -e "        -h,  --help"
    echo -e "                Shows help."
    echo -e ""
    echo -e "        -i, --indexer-hostname <hostname>"
    echo -e "                Specifies the Wazuh indexer hostname or IP."
    echo -e ""
    echo -e "        -p, --indexer-password <password>"
    echo -e "                Specifies the Wazuh indexer admin user password."
    echo -e ""
    echo -e "        -P, --priority <priority>"
    echo -e "                Specifies the policy's priority."
    echo -e ""
    echo -e "        -s, --min-shard-size <shard-size>"
    echo -e "                Set the minimum shard size in GB. By default 25."
    echo -e ""
    echo -e "        -v, --verbose"
    echo -e "                Set verbose mode. Prints more information."
    echo -e ""
    exit 1
}

#########################################################################
# Main function.
#########################################################################
function main() {
    # The list should contain every alias which indices implement the
    # rollover policy
    aliases=("wazuh-alerts" "wazuh-archives")

    while [ -n "${1}" ]; do
        case "${1}" in
        "-a" | "--min-index-age")
            if [ -z "${2}" ]; then
                echo "Error on arguments. Probably missing <index-age> after -a|--min-index-age"
                show_help
            else
                MIN_INDEX_AGE="${2}"
                shift 2
            fi
            ;;
        "-d" | "--min-doc-count")
            if [ -z "${2}" ]; then
                echo "Error on arguments. Probably missing <doc-count> after -d|--min-doc-count"
                show_help
            else
                MIN_DOC_COUNT="${2}"
                shift 2
            fi
            ;;
        "-h" | "--help")
            show_help
            ;;
        "-i" | "--indexer-hostname")
            if [ -z "${2}" ]; then
                echo "Error on arguments. Probably missing <hostname> after -i|--indexer-hostname"
                show_help
            else
                INDEXER_HOSTNAME="${2}"
                INDEXER_URL="https://${INDEXER_HOSTNAME}:9200"
                shift 2
            fi
            ;;
        "-p" | "--indexer-password")
            if [ -z "${2}" ]; then
                echo "Error on arguments. Probably missing <password> after -p|--indexer-password"
                show_help
            else
                INDEXER_PASSWORD="${2}"
                C_AUTH="-u admin:${INDEXER_PASSWORD}"
                shift 2
            fi
            ;;
        "-s" | "--min-shard-size")
            if [ -z "${2}" ]; then
                echo "Error on arguments. Probably missing <shard-size> after -s|--min-shard-size"
                show_help
            else
                MIN_SHARD_SIZE="${2}"
                shift 2
            fi
            ;;
        "-P" | "--priority")
            if [ -z "${2}" ]; then
                echo "Error on arguments. Probably missing <priority> after -P|--priority"
                show_help
            else
                ISM_PRIORITY="${2}"
                shift 2
            fi
            ;;
        "-v" | "--verbose")
            set -x
            shift
            ;;
        *)
            echo "Unknow option: ${1}"
            show_help
            ;;
        esac
    done

    # Load the Wazuh Indexer templates
    # Upload the rollover policy
    # Create the initial write indices
    if load_templates && upload_rollover_policy && create_indices "${aliases[@]}"; then
        echo "SUCC: Indexer ISM initialization finished successfully."
    else
        echo "ERROR: Indexer ISM initialization failed. Check ${LOG_FILE} for more information."
        exit 1
    fi
}

main "$@"
