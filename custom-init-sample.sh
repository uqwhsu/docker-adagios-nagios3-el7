#!/usr/bin/env sh

# Install speedtest-cli
pip install speedtest-cli

# Install nagios plugin
speedtest_script=/usr/lib64/nagios/plugins/check_speedtest-cli.sh
if [[ ! -x "$speedtest_script" ]]
then
    curl "http://exchange.nagios.org/components/com_mtree/attachment.php?link_id=5654&cf_id=29" | sed 's|STb=|STb=/usr/bin|' > "$speedtest_script"
    chmod +x "$speedtest_script"
fi
