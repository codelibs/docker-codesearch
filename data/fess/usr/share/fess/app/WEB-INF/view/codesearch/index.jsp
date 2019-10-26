<%@page pageEncoding="UTF-8" contentType="text/html; charset=UTF-8"%>
<%@ page import="org.codelibs.fess.util.ComponentUtil" %>
<% request.setAttribute("facetResponse", ComponentUtil.getViewHelper().getCachedFacetResponse("*:*"));
%><!DOCTYPE html>
<html>
<head profile="http://a9.com/-/spec/opensearch/1.1/">
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta http-equiv="X-UA-Compatible" content="IE=edge">
<title>Code Search</title>
<%@ include file="gtmHead.jsp" %>
<c:if test="${osddLink}">
	<link rel="search" type="application/opensearchdescription+xml"
		href="${fe:url('/osdd')}"
		title="<la:message key="labels.index_osdd_title" />" />
</c:if>
<link href="${fe:url('/css/bootstrap.min.css')}" rel="stylesheet"
	type="text/css" />
<link href="${fe:url('/css/codesearch/style.css')}" rel="stylesheet" type="text/css" />
<link href="${fe:url('/css/font-awesome.min.css')}" rel="stylesheet"
	type="text/css" />
<%@ include file="adsenseHead.jsp" %>
</head>
<body>
<%@ include file="gtmBody.jsp" %>
	<la:form action="/search" method="get" styleId="searchForm">
		${fe:facetForm()}${fe:geoForm()}
		<header>
			<nav class="navbar navbar-expand-md navbar-dark fixed-top bg-navy">
				<div id="content" class="container">
					<div class="navbar-brand"></div>
					<button class="navbar-toggler" type="button" data-toggle="collapse" data-target="#navbar"
							aria-controls="navbar" aria-expanded="false" aria-label="Toggle navigation">
						<span class="navbar-toggler-icon"></span>
					</button>
					<div class="collapse navbar-collapse" id="navbar">
						<div class="mr-auto"></div>
						<ul class="nav navbar-nav">
							<c:choose>
								<c:when test="${!empty username && username != 'guest'}">
									<li class="nav-item">
										<div class="dropdown">
											<a class="nav-link dropdown-toggle" data-toggle="dropdown"
												href="#" role="button" aria-haspopup="true"
												aria-expanded="false"> <em class="fa fa-fw fa-user"></em>${username}
											</a>
											<div class="dropdown-menu" aria-labelledby="userMenu">
												<c:if test="${editableUser == true}">
													<la:link href="/profile" styleClass="dropdown-item">
														<la:message key="labels.profile" />
													</la:link>
												</c:if>
												<c:if test="${adminUser == true}">
													<la:link href="/admin" styleClass="dropdown-item">
														<la:message key="labels.administration" />
													</la:link>
												</c:if>
												<la:link href="/logout/" styleClass="dropdown-item">
													<la:message key="labels.logout" />
												</la:link>
											</div>
										</div>
									</li>
								</c:when>
								<c:when test="${ pageLoginLink }">
									<li class="nav-item"><la:link href="/login"
											styleClass="nav-link" role="button" aria-haspopup="true"
											aria-expanded="false">
											<em class="fa fa-fw fa-sign-in"></em>
											<la:message key="labels.login" />
										</la:link></li>
								</c:when>
							</c:choose>
							<li class="nav-item"><a href="https://github.com/codelibs/docker-codesearch"
									class="nav-link help-link" target="_blank">
									<em class="fab fa-github"></em>
								</a></li>
							<li class="nav-item"><la:link href="/help"
									styleClass="nav-link help-link">
									<em class="fa fa-fw fa-question-circle"></em>
									<la:message key="labels.index_help" />
								</la:link></li>
						</ul>
					</div>
				</div>
			</nav>
		</header>
		<div id="searchOptions" class="control-options">
			<div class="container">
				<jsp:include page="searchOptions.jsp" />
				<div>
					<button type="button" class="btn btn-light" id="searchOptionsClearButton">
						<la:message key="labels.search_options_clear" />
					</button>
					<button type="submit" class="btn btn-primary">
						<em class="fa fa-search"></em>
						<la:message key="labels.search" />
					</button>
					<la:link href="/search/advance" styleClass="btn btn-info">
						<em class="fa fa-cog"></em>
						<la:message key="labels.advance" />
					</la:link>
				</div>
			</div>
		</div>
		<main class="container">
			<div class="row">
				<div class="col text-center searchFormBox">
					<h1 class="mainLogo">
						<img src="${fe:url('/images/codesearch/logo.png')}"
							alt="<la:message key="labels.index_title" />" />
					</h1>
					<div class="notification">${notification}</div>
					<div>
						<la:info id="msg" message="true">
							<div class="alert alert-info">${msg}</div>
						</la:info>
						<la:errors header="errors.front_header"
							footer="errors.front_footer" prefix="errors.front_prefix"
							suffix="errors.front_suffix" />
					</div>
					<fieldset>
						<legend><la:message key="labels.search" /></legend>
						<div class="clearfix">
							<div class="mx-auto col-10 col-sm-8 col-md-8 col-lg-6">
								<la:text styleClass="query form-control center-block"
									property="q" size="50" maxlength="1000" styleId="contentQuery"
									autocomplete="off" />
							</div>
						</div>
						<c:if test="${!empty popularWords}">
							<div class="clearfix">
								<p class="text-truncate">
									<la:message key="labels.search_popular_word_word" />
									<c:forEach var="item" varStatus="s" items="${popularWords}">
										<c:if test="${s.index < 3}">
											<la:link
												href="/search?q=${f:u(item)}${fe:facetQuery()}${fe:geoQuery()}">${f:h(item)}</la:link>
										</c:if>
										<c:if test="${3 <= s.index}">
											<la:link styleClass="d-none d-sm-inline"
												href="/search?q=${f:u(item)}${fe:facetQuery()}${fe:geoQuery()}">${f:h(item)}</la:link>
										</c:if>
									</c:forEach>
								</p>
							</div>
						</c:if>
						<div class="clearfix searchButtonBox btn-group">
							<button type="submit" name="search" id="searchButton"
								class="btn btn-primary">
								<em class="fa fa-search"></em>
								<la:message key="labels.index_form_search_btn" />
							</button>
							<button type="button" class="btn btn-outline-secondary"
								data-toggle="control-options" data-target="#searchOptions"
								id="searchOptionsButton">
								<em class="fa fa-cog"></em>
								<la:message key="labels.index_form_option_btn" />
							</button>
						</div>
					</fieldset>
				</div>
			</div>
			<c:if test="${facetResponse != null}">
				<div class="row">
				<c:forEach var="fieldData" items="${facetResponse.fieldList}">
					<c:if test="${fieldData.valueCountMap.size() > 0}">
					<div class="col-md-4">
					<ul class="list-group mb-2">
						<li class="list-group-item text-uppercase">${f:h(fieldData.name)}</li>
						<c:forEach var="countEntry" items="${fieldData.valueCountMap}">
							<c:if test="${countEntry.value != 0}">
							<li class="list-group-item">
								<la:link href="/search?q=${f:u(fieldData.name)}%3a${f:u(countEntry.key)}${fe:pagingQuery(null)}${fe:facetQuery()}${fe:geoQuery()}">
								${f:h(countEntry.key)}
								<span class="badge badge-secondary badge-pill float-right">${f:h(countEntry.value)}</span>
								</la:link></li>
							</c:if>
						</c:forEach>
					</ul>
					</div>
					</c:if>
				</c:forEach>
				<c:forEach var="facetQueryView" items="${fe:facetQueryViewList()}">
					<div class="col-md-4">
					<ul class="list-group mb-2">
						<li class="list-group-item text-uppercase"><la:message
								key="${facetQueryView.title}" /></li>
						<c:set var="facetFound" value="F"/>
						<c:forEach var="queryEntry" items="${facetQueryView.queryMap}">
							<c:if test="${facetResponse.queryCountMap[queryEntry.value] > 0}">
								<li class="list-group-item"><la:link
										href="/search?q=${f:u(queryEntry.value)}${fe:pagingQuery(queryEntry.value)}${fe:facetQuery()}${fe:geoQuery()}">
										<c:if test="${fn:startsWith(queryEntry.key, 'labels.')}"><la:message key="${queryEntry.key}" /></c:if>
										<c:if test="${not fn:startsWith(queryEntry.key, 'labels.')}">${f:h(queryEntry.key)}</c:if>
										<span class="badge badge-secondary badge-pill float-right">${f:h(facetResponse.queryCountMap[queryEntry.value])}</span>
									</la:link></li>
								<c:set var="facetFound" value="T"/>
							</c:if>
						</c:forEach>
						<c:if test="${facetFound == 'F'}">
							<li class="list-group-item"><la:message key="labels.facet_is_not_found" /></li>
						</c:if>
					</ul>
					</div>
				</c:forEach>
				<c:if test="${!empty ex_q}">
					<div class="float-right">
						<la:link href="/search?q=${f:u(q)}"
							styleClass="btn btn-link btn-sm">
							<la:message key="labels.facet_label_reset" />
						</la:link>
					</div>
				</c:if>
				</div>
			</c:if>
		</main>
		<jsp:include page="footer.jsp" />
	</la:form>
	<input type="hidden" id="contextPath" value="${contextPath}" />
	<script type="text/javascript"
		src="${fe:url('/js/jquery-3.4.0.min.js')}"></script>
	<script type="text/javascript" src="${fe:url('/js/bootstrap.min.js')}"></script>
	<script type="text/javascript" src="${fe:url('/js/suggestor.js')}"></script>
	<script type="text/javascript" src="${fe:url('/js/index.js')}"></script>
</body>
</html>
