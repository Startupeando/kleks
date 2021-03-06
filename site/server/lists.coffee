templates = require('duality/templates')
dutils    = require('duality/utils')
settings  = require('settings/root')
Showdown  = require('showdown')
_         = require('underscore')._
utils     = require('lib/utils')
moment    = require('lib/moment')


exports.home = (head, req) ->
  # no need for double render on first hit
  return if req.client and req.initial_hit
  start code: 200, headers: {'Content-Type': 'text/html'}

  md = new Showdown.converter()
  collections = []
  blocks = {}
  site = {}

  while row = getRow()
    doc = row.value
    if doc
      collections.push(doc) if doc.type is 'collection'
      blocks[doc.code] = doc if doc.type is 'block'
      site = doc if doc.type is 'site'
  
  collections = _.map collections, (doc) ->
    if doc.intro?
      doc.intro_html = md.makeHtml(
        doc.intro.replace(/\{\{?baseURL\}?\}/g, dutils.getBaseURL(req))
      )
    doc.updated_at_html = utils.prettyDate(doc.updated_at)
    doc.updated_at_half = utils.halfDate(doc.updated_at)
    doc.fresh = utils.isItFresh(doc.updated_at)
    doc.type_tc = utils.capitalize(doc.type)
    return doc

  return {
    on_dev: utils.isDev(req)
    area: 'home'
    site: site
    type: 'home'
    title: "#{site.name}"
    content: templates.render "home.html", req,
      collections: collections
      blocks: blocks
    og:
      site_name: site.name
      title: site.name
      description: site.seo_description
      type: 'website'
      url: site.link
      image: "#{site.link}/file/#{blocks.site_intro._id}/#{blocks.site_intro.photo}" if blocks.site_intro?.photo
  }


exports.collection = (head, req) ->
  # no need for double render on first hit
  return if req.client and req.initial_hit
  start code: 200, headers: {'Content-Type': 'text/html'}

  md = new Showdown.converter()
  docs = []
  collection = null
  blocks = {}
  sponsor = null
  site = {}

  while row = getRow()
    doc = row.doc
    if doc
      docs.push(doc) if doc.type in settings.app.content_types
      collection ?= doc if doc.type is 'collection'
      blocks[doc.code] = doc if doc.type is 'block'
      sponsor ?= doc if doc.type is 'sponsor'
      site = doc if doc.type is 'site'

  if collection
    if collection.intro?
      collection.intro_html = md.makeHtml(
        collection.intro.replace(/\{\{?baseURL\}?\}/g, dutils.getBaseURL(req))
      )
    collection.fresh = utils.isItFresh(collection.updated_at)
    collection.type_tc = utils.capitalize(collection.type)

  docs = _.map docs, (doc) ->
    if doc.intro?
      doc.intro_html = md.makeHtml(
        doc.intro.replace(/\{\{?baseURL\}?\}/g, dutils.getBaseURL(req))
      )
    doc.published_at_html = utils.prettyDate(doc.published_at)
    doc.fresh = utils.isItFresh(doc.published_at)
    doc.type_tc = utils.capitalize(doc.type)
    if doc.type is 'scene'
      doc.list_item_template = 'partials/list-item-scene.html'
    else
      doc.list_item_template = 'partials/list-item-default.html'
    return doc

  if sponsor
    # Check for strat/end dates of sponsorship
    sponsor_start = moment.utc(collection.sponsor_start)
    sponsor_end = moment.utc(collection.sponsor_end)
    now = moment.utc()
    if sponsor_start.diff(now) <= 0 and sponsor_end.diff(now) >= 0
      # let's continue on
      sponsor.text_format = sponsor.format is 'text'
      sponsor.image_format = sponsor.format is 'image'
      sponsor.video_format = sponsor.format is 'video'
      sponsor.embed_format = sponsor.format is 'embed'
      sponsor.for_type = collection.type
      sponsor.for_type_tc = collection.type_tc
      # Let's also pass the site's default ad unit if asked for it
      if site and site.default_ad_unit and site.default_ad_enabled and sponsor.include_default_ad_unit
        sponsor.content = site.default_ad_unit + sponsor.content
    else
      # let's remove the sponsor
      sponsor = null

  if collection
    if not sponsor and site and site.default_ad_unit and site.default_ad_enabled
      # In this case create a new sponsor object and use
      # the site's default ad unit if enabled
      sponsor = {}
      sponsor.content = site.default_ad_unit
      sponsor.embed_format = true
      sponsor.for_type = collection.type
      sponsor.for_type_tc = collection.type_tc

    return {
      on_dev: utils.isDev(req)
      area: 'collection'
      site: site
      type: 'collection'
      title: collection.name
      content: templates.render 'collection.html', req,
        collection: collection
        docs: docs
        sponsor: sponsor
        blocks: blocks
      og:
        site_name: site.name
        title: collection.name
        description: collection.intro
        type: 'website'
        url: "#{site.link}/collection/#{collection.slug}"
        image: "#{site.link}/file/#{collection._id}/#{collection.photo}" if collection.photo
    }
  else
    return {
      code: 404
      title: '404 Not Found'
      content: templates.render '404.html', req, { host: req.headers.Host }
      on_dev: utils.isDev(req)
      area: '404'
    }


exports.docs = (head, req) ->
  # no need for double render on first hit
  return if req.client and req.initial_hit
  start code: 200, headers: {'Content-Type': 'text/html'}

  md = new Showdown.converter()
  docs = []
  site = {}

  while row = getRow()
    doc = row.doc
    if doc
      if doc.type in settings.app.content_types
        doc.collection_docs = []
        docs.push(doc)
      else if doc.type is 'collection'
        # Add the collection doc to the last doc pushed
        docs[docs.length-1].collection_docs.push(doc)
      site = doc if doc.type is 'site'

  docs = _.map docs, (doc) ->
    if doc.intro?
      doc.intro_html = md.makeHtml(
        doc.intro.replace(/\{\{?baseURL\}?\}/g, dutils.getBaseURL(req))
      )
    doc.published_at_html = utils.prettyDate(doc.published_at)
    doc.updated_at_html = utils.prettyDate(doc.updated_at)
    doc.fresh = utils.isItFresh(doc.published_at)
    doc.type_tc = utils.capitalize(doc.type)
    if doc.type is 'scene'
      doc.list_item_template = 'partials/list-item-scene.html'
    else
      doc.list_item_template = 'partials/list-item-default.html'
    return doc

  return {
    on_dev: utils.isDev(req)
    area: 'docs'
    site: site
    type: 'docs'
    title: 'Docs List'
    content: templates.render 'docs.html', req,
      docs: docs
    og:
      site_name: site.name
      title: site.name
      description: site.seo_description
      type: 'website'
      url: site.link
  }


exports.doc = (head, req) ->
  ###
  This will render the content doc along with a list of its
  associated collections.
  ###
  # no need for double render on first hit
  return if req.client and req.initial_hit
  start code: 200, headers: {'Content-Type': 'text/html'}

  md = new Showdown.converter()
  theDoc = null
  collections = []
  blocks = []
  author = null
  sponsor = null
  site = {}

  while row = getRow()
    doc = row.doc
    if doc
      theDoc ?= doc if doc.type in settings.app.content_types
      collections.push(doc) if doc.type is 'collection'
      blocks.push(doc) if doc.type is 'block'
      sponsor ?= doc if doc.type is 'sponsor'
      author ?= doc if doc.type is 'author'
      site = doc if doc.type is 'site'

  # Let's just go back and use `doc` as the variable instead
  doc = theDoc

  transformDoc = (doc) ->
    doc.intro_html = md.makeHtml(replaceTokens(doc.intro)) if doc.intro?
    doc.body_html = md.makeHtml(replaceTokens(doc.body))
    doc.published_at_html = utils.prettyDate(doc.published_at)
    doc.updated_at_html = utils.prettyDate(doc.updated_at)
    doc.fresh = utils.isItFresh(doc.published_at)
    doc.type_tc = utils.capitalize(doc.type)
    return doc

  replaceTokens = (content) ->
    # Replace the {baseURL} or {{baseURL}} token
    content = content.replace(/\{\{?baseURL\}?\}/g, dutils.getBaseURL(req))
    # Replace any references to the extra doc's blocks
    # within the doc e.g. "<!-- block: some_code_or_id -->"  (optionally without spaces)
    for block in blocks
      if block.enabled
        re = new RegExp('<!--\\s*block:\\s*(' + block._id + '|' + block.code + ')\\s*-->', 'gi')
        content = content.replace(re, block.content)
    return content

  doc = transformDoc(doc) if doc

  collections = _.map collections, (doc) ->
    if doc.intro?
      doc.intro_html = md.makeHtml(
        doc.intro.replace(/\{\{?baseURL\}?\}/g, dutils.getBaseURL(req))
      )
    doc.updated_at_html = utils.prettyDate(doc.updated_at)
    doc.fresh = utils.isItFresh(doc.updated_at)
    return doc

  collection = collections?[0] # primary one

  if sponsor
    # Check for strat/end dates of sponsorship
    sponsor_start = moment.utc(doc.sponsor_start)
    sponsor_end = moment.utc(doc.sponsor_end)
    now = moment.utc()
    if sponsor_start.diff(now) <= 0 and sponsor_end.diff(now) >= 0
      # let's continue on
      sponsor.text_format = sponsor.format is 'text'
      sponsor.image_format = sponsor.format is 'image'
      sponsor.video_format = sponsor.format is 'video'
      sponsor.embed_format = sponsor.format is 'embed'
      sponsor.for_type = doc.type
      sponsor.for_type_tc = doc.type_tc
      # Let's also pass the site's default ad unit if asked for it
      if site and site.default_ad_unit and site.default_ad_enabled and sponsor.include_default_ad_unit
        sponsor.content = site.default_ad_unit + sponsor.content
    else
      # let's remove the sponsor
      sponsor = null

  # Let's use the collection's sponsor if there was no doc sponsor
  # and the sponsor was setup to propogate to entire collection's docs
  if not sponsor and collection and collection.sponsor_id and collection.sponsor_propagate
    # Check for strat/end dates of sponsorship
    sponsor_start = moment.utc(collection.sponsor_start)
    sponsor_end = moment.utc(collection.sponsor_end)
    now = moment.utc()
    if sponsor_start.diff(now) <= 0 and sponsor_end.diff(now) >= 0
      sponsor =
        load_on_client: true
        collection_id: collection._id
        sponsor_id: collection.sponsor_id
      # Let's also pass the site's default ad unit in case we like to use it
      if site and site.default_ad_unit and site.default_ad_enabled
        sponsor.default_ad_unit = site.default_ad_unit

  if doc
    if not sponsor and site and site.default_ad_unit and site.default_ad_enabled
      # In this case create a new sponsor object and use
      # the site's default ad unit if enabled
      sponsor = {}
      sponsor.content = site.default_ad_unit
      sponsor.embed_format = true
      sponsor.for_type = doc.type
      sponsor.for_type_tc = doc.type_tc

    return {
      on_dev: utils.isDev(req)
      area: 'doc'
      site: site
      type: doc.type
      title: doc.title
      content: templates.render 'doc.html', req,
        doc: doc
        collections: collections
        collection: collection
        author: author
        sponsor: sponsor
        blocks: blocks
      og:
        site_name: site.name
        title: doc.title
        description: doc.intro
        type: 'article'
        url: "#{site.link}/#{doc.type}/#{doc.slug}"
        image: "#{site.link}/file/#{doc._id}/#{doc.photo}" if doc.photo
        first_name: author?.name.split(' ')[0]
        last_name: author?.name.split(' ')[1]
        published: doc.published_at
    }
  else
    return {
      code: 404
      title: '404 Not Found'
      content: templates.render '404.html', req, { host: req.headers.Host }
      on_dev: utils.isDev(req)
      area: '404'
    }


exports.rssfeed = (head, req) ->
  start code: 200, headers: {'Content-Type': 'application/xml'}
  # Output as plain text for troubleshooting
  # start code: 200, headers: {'Content-Type': 'text/plain'}

  md = new Showdown.converter()
  docs = []
  site = {}

  while row = getRow()
    doc = row.doc
    if doc
      docs.push(doc) if doc.type in settings.app.content_types
      site = doc if doc.type is 'site'

  docs = _.map docs, (doc) ->
    doc.intro_html = ''
    if doc.intro?
      doc.intro_html = md.makeHtml(
        doc.intro.replace(/\{\{?baseURL\}?\}/g, dutils.getBaseURL(req))
      )
    doc.intro_html = "<p><img src=\"#{site.link}/file/#{doc._id}/#{doc.photo}\" style=\"display: block; max-width: 100%;\"></p>" + doc.intro_html if doc.photo
    doc.intro_html = doc.intro_html + doc.video if doc.video
    doc.body_html = md.makeHtml(
      doc.body.replace(/\{\{?baseURL\}?\}/g, dutils.getBaseURL(req))
    )
    doc.published_at = moment.utc(doc.published_at).toDate().toGMTString()
    doc.full_url = "#{site.link}/#{doc.type}/#{doc.slug}"
    doc.full_html = "#{doc.intro_html} #{doc.body_html}"
    return doc

  return templates.render 'feed.xml', req,
    site: site
    docs: docs
    build_date: moment.utc().toDate().toGMTString()


exports.sitemap = (head, req) ->
  start code: 200, headers: {'Content-Type': 'application/xml'}

  docs = []
  siteLink = ''

  while row = getRow()
    key = row.key
    date = key[1]
    type = key[2]
    slug = key[3]
    log key
    if type is 'site'
      siteLink = slug if not siteLink
    else
      docs.push
        url: "#{siteLink}/#{type}/#{slug}"
        date: date

  return templates.render 'sitemap.xml', req,
    docs: docs
