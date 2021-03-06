#' @title Download an OpenML flow.
#'
#' @description
#' Given an flow id, the corresponding \code{\link{OMLFlow}} is
#' downloaded if not already available in cache.
#'
#' @template arg_flow.id
#' @template arg_cache_only
#' @template arg_verbosity
#' @return [\code{\link{OMLFlow}}].
#' @family downloading functions
#' @family flow-related functions
#' @example /inst/examples/getOMLFlow.R
#' @export
getOMLFlow = function(flow.id, cache.only = FALSE, verbosity = NULL) {
  flow.id = asCount(flow.id)
  assertFlag(cache.only)

  down = downloadOMLObject(flow.id, object = "flow", cache.only = cache.only, verbosity = verbosity)
  flow = parseOMLFlow(down$doc)

  # is there another file except the flow.xml?
  file.exist = !(names(down$files) %in% "flow.xml")
  if (any(file.exist)) {
    file = down$files[[which(file.exist)]]
    if (file$binary) flow$binary.path = file$path else flow$source.path = file$path
  }

  return(flow)
}

# returns the version contained in the external.version slot, e.g. for R_3.2.4-v2.b4a3f309,
# it returns 2 (which, if available, is the number between "-v" and "." and else 0 is returned)

getFlowExternalVersion = function(flow) {
  assertClass(flow, "OMLFlow")

  has.version = stri_detect_regex(flow$external.version, "-v[[:digit:]]*[.]")
  if (has.version) {
    flow.version = stri_replace_all_regex(flow$external.version, ".*-v|[.].*", "")
  } else flow.version = 0

  return(as.integer(flow.version))
}

parseOMLFlow = function(doc) {
  args = filterNull(list(
    flow.id = xmlRValI(doc, "/oml:flow/oml:id"),
    uploader = xmlOValI(doc, "/oml:flow/oml:uploader"),
    name = xmlRValS(doc, "/oml:flow/oml:name"),
    version = xmlRValS(doc, "/oml:flow/oml:version"),
    external.version = xmlOValS(doc, "/oml:flow/oml:external_version"),
    description = xmlRValS(doc, "/oml:flow/oml:description"),
    creator = xmlOValsMultNsS(doc, "/oml:flow/oml:creator"),
    contributor = xmlOValsMultNsS(doc, "/oml:flow/oml:contributor"),
    upload.date = xmlRValS(doc, "/oml:flow/oml:upload_date"),
    licence = xmlOValS(doc, "/oml:flow/oml:licence"),
    language = xmlOValS(doc, "/oml:flow/oml:language"),
    full.description = xmlOValS(doc, "/oml:flow/oml:full_description"),
    installation.notes = xmlOValS(doc, "/oml:flow/oml:installation_notes"),
    dependencies = xmlOValS(doc, "/oml:flow/oml:dependencies"),
    bibliographical.reference = parseOMLBibRef(doc),
    implements = xmlOValS(doc, "/oml:flow/oml:implements"),
    parameters = parseOMLParameters(doc),
    qualities = parseOMLQualities(doc),
    tags = xmlOValsMultNsS(doc, "/oml:flow/oml:tag"),
    source.url = xmlOValS(doc, "/oml:flow/oml:source_url"),
    binary.url = xmlOValS(doc, "/oml:flow/oml:binary_url"),
    source.format = xmlOValS(doc, "/oml:flow/oml:source_format"),
    binary.format = xmlOValS(doc, "/oml:flow/oml:binary_format"),
    source.md5 = xmlOValS(doc, "/oml:flow/oml:source_md5"),
    binary.md5 = xmlOValS(doc, "/oml:flow/oml:binary_md5"),
    components = list()
  ))

  ## components section
  comp_ns = getNodeSet(doc, "/oml:flow/oml:component/oml:flow")
  comp = vector("list", length = length(comp_ns))
  for (i in seq_along(comp_ns)) {
    # save subcomponent temporarily on disk
    # FIXME: this is not very elegant
    file2 = tempfile("components")
    saveXML(comp_ns[[i]], file = file2)
    comp[[i]] = parseOMLFlow(parseXMLResponse(file2, type = "flow"))
    names(comp)[i] = xmlRValS(doc, paste0("/oml:flow/oml:component[", i, "]/oml:identifier"))
    unlink(file2)
  }
  args[["components"]] = comp

  return(do.call(makeOMLFlow, args))
}

parseOMLParameters = function(doc) {
  path = "/oml:flow/oml:parameter"

  ns = getNodeSet(doc, path)
  nr.pars = length(ns)

  par.names = xmlValsMultNsS(doc, sprintf("%s/oml:name", path))
  par.types = xmlOValsMultNsSPara(doc, sprintf("%s/oml:data_type", path), exp.length = nr.pars)
  par.defs = xmlOValsMultNsSPara(doc, sprintf("%s/oml:default_value", path), exp.length = nr.pars)
  par.descs = xmlOValsMultNsSPara(doc, sprintf("%s/oml:description", path), exp.length = nr.pars)
  par.rec.range = xmlOValsMultNsSPara(doc, sprintf("%s/oml:recommendedRange", path), exp.length = nr.pars)

  par = vector("list", length(par.names))
  for (i in seq_along(par)) {
    par[[i]] = makeOMLFlowParameter(name = par.names[i], data.type = par.types[i],
      default.value = par.defs[i], description = par.descs[i], recommended.range = par.rec.range[i])
  }
  return(par)
}

parseOMLBibRef = function(doc) {
  path = "/oml:flow/oml:bibliographical_reference"

  bib.citation = xmlValsMultNsS(doc, sprintf("%s/oml:citation", path))
  bib.url = xmlValsMultNsS(doc, sprintf("%s/oml:url", path))

  bib = Map(function(i) {
    makeOMLBibRef(bib.citation[i], bib.url[i])
  }, seq_along(bib.citation))

  if (length(bib) > 0L)
    return(bib)
  return(NULL)
}

parseOMLQualities = function(doc) {
  path = "/oml:flow/oml:quality"

  name = xmlValsMultNsS(doc, sprintf("%s/oml:name", path))
  value = xmlValsMultNsS(doc, sprintf("%s/oml:value", path))

  qualities = Map(function(i) {
    makeOMLFlowQuality(name[i], value[i])
  }, seq_along(name))

  if (length(qualities) > 0L)
    return(qualities)
  return(NULL)
}
