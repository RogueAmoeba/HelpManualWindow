(function() {

    window.onload = function()
    {
	  	var root = (typeof exports == 'undefined' ? window : exports);

		if (root.devicePixelRatio <= 1)
		{
			var images = document.getElementsByTagName("img");
		
			for( var i = 0; i < images.length; i++)
				images[i].width /= 2;
		}
	}


})();
