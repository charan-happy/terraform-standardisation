bucket         = "${bucket}"
key            = "${key}"
region         = "${region}"
encrypt        = true
%{ if enable_locking ~}
dynamodb_table = "${dynamodb_table}"
%{ endif ~}
