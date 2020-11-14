function surfs  = myfs_readsurfs (subid, subjects_dir, cfg)
% reads multiple surfaces, maps, & annotations from FreeSurfer results.
%
% [USAGE]
% surfs = fsss_readsurfs (subid, [subjects_dir], [cfg])
%
% [INPUT]
% subid        '1xN' subject directory name
% subjects_dir '1xN' directory where you have the subject directory
% cfg          (1x1) configuration structure:
% .surf  {1xN} surfaces to read. 
%              DEFAULT: 'white','pial','inflated' 'smoothwm'
%              OPTIONAL: 'sphere','mean','semiinflated', or any surface
%              files in <surf> directory
%
% .meas  {1xN} measures to read
%              DEFAULT: 'thickness','curv',
%              OPTIONAL: 'sulc','area', or any curvature files in <surf>
%              directory
%
% .annot {1xN} annotations to read
%              DEFAULT: 'aparc', 'aparc.a2009s'
%              OPTIONAL: 'aparc.DKTatlas40', 'BA', or any .ANNOT files in
%              <label> directory
% 
% .isocurv {1xN} surfaces to create .isocurv field (it may take time)
%                DEFAULT: []
%
% .outerbnd {1xN} surfaces to create .outer field (it may take time)
%                 DEFAULT: []
%
%
% .smooth [1x1] # of iterations of smoothing
%
% [OUTPUT]
% surfs   (1x1) structure:
% .(surfaces) {1x2}
% .(measures) {1x2}
% .(annotations) {1x2}
%
%
% [EXAMPLES]
% surfs = myfs_readsurfs('bert');
% surfs = myfs_readsurfs('bert', '/usr/local/freesurfer/subjects');
% surfs = myfs_readsurfs('bert', '/usr/local/freesurfer/subjects', ...
%         struct('meas',{{'thickness','curv','area','sulc'}}) );
%
% (cc) 2020, sgKIM, solleo@gmail.com

%% CHECK inputs & SET default values
if ~nargin
  help(mfilename)
  return
end
myfs_addpath()

if exist('subjects_dir','var') && ~isempty(subjects_dir)
  setenv('SUBJECTS_DIR',subjects_dir);
else
  subjects_dir = getenv('SUBJECTS_DIR');
end
dname = fullfile(subjects_dir, subid);
if ~isfolder(dname)
  error('%s NOT FOUND!',dname)
end
if ~exist('read_surf','file')
  error('FreeSurfer matlab functions are not in path!')
end

if ~exist('cfg','var')
  cfg = [];
end
if ~isfield(cfg,'surf')
  cfg.surf = {'white','pial','inflated','smoothwm'};
end
if ~isfield(cfg,'meas')
  cfg.meas = {'thickness','curv'};
end
if ~isfield(cfg,'annot')
  cfg.annot = {'aparc','aparc.a2009s'};
end
if ~isfield(cfg,'isocurv')
  cfg.isocurv = {};
end
if ~isfield(cfg,'outerbnd')
  cfg.outerbnd = {};
end
if ~isfield(cfg,'smooth')
  cfg.smooth = 0;
end

% make sure all fields are cell arraies:
fieldnames = {'surf','meas','annot','isocurv'};
for ifield = 1:4
  this = fieldnames{ifield};
  if ~iscell(cfg.(this)) && ~isempty(cfg.(this))
    cfg.(this) = {cfg.(this)};
  end
end


%% CREATE custom surfaces if necessary
hemis = {'lh.','rh.'};
surfs2create = intersect(cfg.surf,{'mean','semiinflated'});
for isurf = 1:numel(surfs2create)
  surfname = surfs2create{isurf};
  isdone = true;
  for ihemi = 1:2
    isdone = isdone && isfile(...
      fullfile(dname, 'surf', [hemis{ihemi} surfname]));
  end
  if ~isdone
    myfs_createsurf (subid, subjects_dir, surfname);
  end
end


%% READ surfaces
surfs = [];
for isurf = 1:numel(cfg.surf)
  surfname = cfg.surf{isurf};
  for ihemi = 1:2
    fname = fullfile(dname, 'surf', [hemis{ihemi} surfname]);
    if cfg.smooth
      fname_temp = tempname;
      system(sprintf('mris_smooth -nw -n %i %s %s',...
        cfg.smooth, fname, fname_temp));
      fname = fname_temp;
    end
    [V, F] = read_surf(fname);
    F = F + 1; % 1-based indexing in matlab
    surfs.(surfname){ihemi} = struct(...
      'vertices',single(V), 'faces',uint32(F));
  end
end


%% READ measures
for imeas = 1:numel(cfg.meas)
  measname = cfg.meas{imeas};
  for ihemi = 1:2
    fname = fullfile(dname, 'surf', [hemis{ihemi} measname]);
    [C] = read_curv(fname);
    surfs.(measname){ihemi} = single(C);
  end
end


%% READ annotations
for iann = 1:numel(cfg.annot)
  annname = cfg.annot{iann};
  for ihemi = 1:2
    fname = fullfile(dname, 'label', [hemis{ihemi} annname '.annot']);
    [verts, label, cot] = read_annotation(fname, 0);
    assert(all(verts'==0:verts(end)),...
      'Annotation file %s: Not all vertices are defined!')
    
    iscortex = ~~label;
    iscortex(ismember(label, ...
      cot.table(ismember(cot.struct_names,...
      {'unknown','corpuscallosum', ... % aparc, BA, aparc.DKTatlas40
      'Medial_wall','Unknown', ...     % aparc.a2009s
      }),5))) = false;
    
    surfs.(strrep(annname,'.','_')){ihemi} = struct(...
      'label', uint32(label), 'cot', cot, 'cortex', iscortex);
  end
end


%% ADD isocurvature
for isurf = 1:numel(cfg.isocurv)
  surfname = cfg.isocurv{isurf};
  for ihemi = 1:2
    [~, C] = tricontourfast(...
      surfs.(surfname){ihemi}, surfs.curv{ihemi}, 0, false);
    surfs.(surfname){ihemi}.isocurv = C.group;
  end
end


%% ADD outer boundaries
for isurf = 1:numel(cfg.outerbnd)
  surfname = cfg.outerbnd{isurf};
  for ihemi = 1:2
    [C] = triouterboundary(surfs.(surfname){ihemi});
    surfs.(surfname){ihemi}.outerboundary = C.group;
  end
end


end
