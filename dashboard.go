/**
 * OpenBmclAPI (Golang Edition)
 * Copyright (C) 2023 Kevin Z <zyxkad@gmail.com>
 * All rights reserved
 * 
 *  This program is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */
package main

import (
	"embed"
	"io"
	"io/fs"
	"mime"
	"net/http"
	"path"
	"strings"
)

//go:generate npm -C dashboard ci
//go:generate npm -C dashboard run build

//go:embed dashboard/dist
var _dsbDist embed.FS
var dsbDist = func() fs.FS {
	s, e := fs.Sub(_dsbDist, "dashboard/dist")
	if e != nil {
		panic(e)
	}
	return s
}()

//go:embed dashboard/dist/index.html
var dsbIndexHtml string

func (cr *Cluster) serveDashboard(rw http.ResponseWriter, req *http.Request, pth string) {
	if req.Method != http.MethodGet && req.Method != http.MethodHead {
		rw.Header().Set("Allow", http.MethodGet+", "+http.MethodHead)
		http.Error(rw, "405 Method Not Allowed", http.StatusMethodNotAllowed)
		return
	}
	if pth != "" {
		fd, err := dsbDist.Open(pth)
		if err == nil {
			defer fd.Close()
			if stat, err := fd.Stat(); err != nil || stat.IsDir() {
				http.NotFound(rw, req)
				return
			}
			name := path.Base(pth)
			typ := mime.TypeByExtension(path.Ext(name))
			if typ == "" {
				typ = "application/octet-stream"
			}
			rw.Header().Set("Content-Type", typ)
			http.ServeContent(rw, req, name, startTime, fd.(io.ReadSeeker))
			return
		}
	}
	rw.Header().Set("Content-Type", "text/html; charset=utf-8")
	http.ServeContent(rw, req, "index.html", startTime, strings.NewReader(dsbIndexHtml))
}