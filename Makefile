IDRIC_SMS_REQUEST ?= idric-sms-request

.PHONY: test

test:
	sh -n services/sms/idric_sms_service.sh
	sh -n tests/sms_service_test.sh
	IDRIC_SMS_REQUEST="$(IDRIC_SMS_REQUEST)" sh tests/sms_service_test.sh
