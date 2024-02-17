#########################################################################
#         ==================================================            #
#         $ Mikrotik RouterOS update script for CloudFlare $            #
#         ==================================================            #
#                                                                       #
# - You need a CloudFlare account & api key (look under settings),      #
#   a zone and A record in it                                           #
# - All variables in first section are obvious,                         #
#   except CFid and CFzoneid                                            #
# - Obtain CFzoneid from Cloudflare Dashboard,                          #
#   on Overview tab scroll down                                         # 
#   To obtain CFid use following command in any unix shell:             #
#    curl -X GET "https://api.cloudflare.com/client/v4/zones/YOUR_ZONE_ID/dns_records?name=YOUR_DOMAIN" -H "Authorization:Bearer $CFtkn" -H "Content-Type: application/json" | python -mjson.tool
# - You can use my Postman script to get those variables                #
# - Enable CFDebug if needed - it'll print some info to logs            #
# - Enable CFcloud if you don't get a public IP on interface            #
# - Put script under /system scripts giving "read,write,ftp" policy access.       #
#   For 6.29 and older "test" policy is also needed.                    #
# - Add script to /system scheduler using it's name in "on-event"       #
# - Requires at least RouterOS 6.44beta75 for multiple header support   #
#                                                                       #
#              Credits for Samuel Tegenfeldt, CC BY-SA 3.0              #
#                        Modified by kiler129                           #
#                        Modified by viritt                             #
#                        Modified by asuna                              #
#                        Modified by mike6715b                          #
#                        Modified by 0x114514                           #
#                                                                       #
#      Tested and working as of February 17, 2024 (on MIPS V7.13.4)     #
#########################################################################

################# CloudFlare variables #################
:local CFDebug "true"
:local CFcloud "false"

:global WANInterface "&intname"

:local CFdomain "&full_domainname"

:local CFtkn "&API_Tokens"

:local CFzoneid "&Zone_ID"

# To obtain CFid use following command in any unix shell:
# curl -X GET "https://api.cloudflare.com/client/v4/zones/YOUR_ZONE_ID/dns_records?name=YOUR_DOMAIN" -H "Authorization:Bearer $CFtkn" -H "Content-Type: application/json" | python -mjson.tool
# do not use your Account ID!!!
:local CFid "&CF_ID"

:local CFrecordType "A"

:local CFrecordTTL "60"

#########################################################################
########################  DO NOT EDIT BELOW  ############################
#########################################################################

:log info "Updating $CFdomain ..."

################# Internal variables #################
:local previousIP ""
:global WANip ""

################# Get current IP from Cloudflare #################
:if ($CFcloud = "false") do={
    #:/ip/dns/cache/flush
    :set previousIP [resolve $CFdomain  server=1.1.1.1];
    :local currentIP [/ip address get [/ip address find interface=$WANInterface ] address];
    :set WANip [:pick $currentIP 0 [:find $currentIP "/"]];
}

######## Write debug info to log #################
:if ($CFDebug = "true") do={
 :log info ("CF: hostname = $CFdomain")
 :log info ("CF: previousIP = $previousIP")
 :log info ("CF: WANip = $WANip")
 :log info ("CF: Command = \"/tool fetch http-method=put mode=https url=\"$CFurl\" http-header-field=\"Authorization:Bearer $CFtkn,content-type:application/json\" output=none http-data=\"{\"type\":\"$CFrecordType\",\"name\":\"$CFdomain\",\"ttl\":$CFrecordTTL,\"content\":\"$WANip\"}\"")
}
  
######## Compare and update CF if necessary #####
:if ($previousIP != $WANip) do={
 :log info ("CF: Updating CF, setting $CFdomain = $WANip")
 /tool fetch http-method=put mode=https url=("https://api.cloudflare.com/client/v4/zones/$CFzoneid/dns_records/$CFid") \
    http-header-field="Authorization:Bearer $CFtkn,content-type:application/json" output=none \
    http-data="{\"type\":\"$CFrecordType\",\"name\":\"$CFdomain\",\"ttl\":$CFrecordTTL,\"content\":\"$WANip\"}"
 /ip dns cache flush
    :if ( [/file get [/file find name=ddns.tmp.txt] size] > 0 ) do={
        /file remove ddns.tmp.txt
        :execute script=":put $WANip" file="ddns.tmp"
    }
} else={
 :log info "CF: No Update Needed!"
}
