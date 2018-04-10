$(function() {

    // $('.collapse').collapse('hide');
    $('.list-group-item.active').parent().parent('.collapse').collapse('show');


    var pages = new Bloodhound({
        datumTokenizer: Bloodhound.tokenizers.obj.whitespace('title'),
        // datumTokenizer: Bloodhound.tokenizers.whitespace,
        queryTokenizer: Bloodhound.tokenizers.whitespace,

        prefetch: baseurl + '/search.json'
    });

    $('#search-box').typeahead({
        minLength: 0,
        highlight: true
    }, {
        name: 'pages',
        display: 'title',
        source: pages
    });

    $('#search-box').bind('typeahead:select', function(ev, suggestion) {
        window.location.href = suggestion.url;
    });


    // Markdown plain out to bootstrap style
    $('#markdown-content-container table').addClass('table');
    $('#markdown-content-container img').addClass('img-responsive');
});

///
// Add Markdown Heading Anchors
// (source: http://blog.parkermoore.de/2014/08/01/header-anchor-links-in-vanilla-javascript-for-github-pages-and-jekyll/)

var anchorForId = function (id) {
  var anchor = document.createElement("a");
  anchor.className = "header-link";
  anchor.href      = "#" + id;
  anchor.innerHTML = "<i class=\"fa fa-leaf\"></i>";
  return anchor;
};

var linkifyAnchors = function (level, containingElement) {
  var headers = containingElement.getElementsByTagName("h" + level);
  for (var h = 0; h < headers.length; h++) {
    var header = headers[h];

    if (typeof header.id !== "undefined" && header.id !== "") {
      header.appendChild(anchorForId(header.id));
    }
  }
};

document.onreadystatechange = function () {
  if (this.readyState === "complete") {
    var contentBlock = document.getElementById("markdown-content-container");
    if (contentBlock) {
      for (var level = 1; level <= 6; level++) {
        linkifyAnchors(level, contentBlock);
      }
    }
  }
};
