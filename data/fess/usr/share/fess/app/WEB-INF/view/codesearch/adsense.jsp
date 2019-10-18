<%@page pageEncoding="UTF-8" contentType="text/html; charset=UTF-8"%>
<%
if (System.getProperty("fess.google_ad_client") != null && !System.getProperty("fess.google_ad_client").isBlank()) {
%>
<script async src="https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js"></script>
<script>
     (adsbygoogle = window.adsbygoogle || []).push({
          google_ad_client: "<%= System.getProperty("fess.google_ad_client") %>",
          enable_page_level_ads: true
     });
</script>
<% 
}
%>
