<%@page pageEncoding="UTF-8" contentType="text/html; charset=UTF-8"%>
<%
if (System.getProperty("fess.google_ad_client") != null && !System.getProperty("fess.google_ad_client").isBlank()) {
%>
<li>
<ins class="adsbygoogle ad_result_top"
     style="display:block"
     data-ad-client="<%= System.getProperty("fess.google_ad_client") %>"
     data-ad-slot="<%= System.getProperty("fess.google_ad_slot_result_top") %>"
     data-ad-format="auto"
     data-full-width-responsive="true"></ins>
<script>
     (adsbygoogle = window.adsbygoogle || []).push({});
</script>
</li>
<% 
}
%>
