if [[ ! -r /etc/os-release ]]; then
  return
fi

while IFS='=' read -r key val; do
  [[ -z "${key}" || "${key}" == \#* ]] && continue
  val="${val#\"}"
  val="${val%\"}"
  val="${val#\'}"
  val="${val%\'}"
  export "OS_${key}=${val}"
done < /etc/os-release
