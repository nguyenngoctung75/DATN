// This file uses stimulus-loading to automatically load all controllers
// defined in the import map under the "controllers" path.

import { application } from 'controllers/application'
import { eagerLoadControllersFrom } from '@hotwired/stimulus-loading'
eagerLoadControllersFrom('controllers', application)
