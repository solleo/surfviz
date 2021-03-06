function SURF  = fsss_read_all_FS_surfs (sesid, subjects_dir, cfg)
% SURF  = fsss_read_all_FS_surfs (sesid, subjects_dir, cfg)
%
%  cfg.flat=1; cfg.flat2=0; cfg.hn=0; cfg.hnn=0; cfg.vnorm =1;
%  cfg.ras=1; cfg.offsetadj=1; cfg.applyxfm=0;
%  cfg.pial=1; cfg.white=1; cfg.mean=1; cfg.inflated=1; cfg.sphere=1;
%  cfg.suptemp=1; cfg.suptemp2=1; cfg.isocurv=[];
%
% 2020-03-24: Now construct isocurvature contours when 
%             cfg.isocurv = <surfname> 'INFL' | 'PIAL' | 'SMOOTHWM' ...
%
% (cc) 2014-2020, sgKIM, solleo@gmail.com

if ~nargin
 help read_all_FS_surfs
 return
end

if exist('subjects_dir','var') && ~isempty(subjects_dir)
 setenv('SUBJECTS_DIR',subjects_dir);
else
 subjects_dir=getenv('SUBJECTS_DIR');
end

if ~exist('cfg', 'var')
 cfg=[];
 cfg.vnorm =1;    cfg.ras=1;
 cfg.offsetadj=0; cfg.area=1;     cfg.applyxfm=0;
 cfg.mean=0;      cfg.sphere=0;   cfg.smoothwm=0;      cfg.smoothpial=0;
 cfg.pial=1;      cfg.white=1;    cfg.inflated=1;
 cfg.suptemp=0;   cfg.suptemp2=0; cfg.suptemp3=0;      cfg.suptemp4=0;
 cfg.flat=0;      cfg.flat2=0;    cfg.hn=0; cfg.hnn=0;
 cfg.isocurv = [];
else
 if ~isfield(cfg,'flat'),       cfg.flat=0;  end
 if ~isfield(cfg,'vnorm'),      cfg.vnorm=1;  end
 if ~isfield(cfg,'ras'),        cfg.ras=1;  end
 if ~isfield(cfg,'flat2'),      cfg.flat2=0;  end
 if ~isfield(cfg,'hn'),         cfg.hn=0;  end
 if ~isfield(cfg,'hnn'),        cfg.hnn=0;  end
 if ~isfield(cfg,'offsetadj'),  cfg.offsetadj=0;  end
 if ~isfield(cfg,'pial'),       cfg.pial=1;  end
 if ~isfield(cfg,'white'),      cfg.white=1;  end
 if ~isfield(cfg,'mean'),       cfg.mean=1;  end
 if ~isfield(cfg,'sphere'),     cfg.sphere=1;  end
 if ~isfield(cfg,'smoothwm'),   cfg.smoothwm=0;  end
 if ~isfield(cfg,'smoothpial'), cfg.smoothpial=0;  end
 if ~isfield(cfg,'suptemp'),    cfg.suptemp=0;  end
 if ~isfield(cfg,'suptemp2'),   cfg.suptemp2=0;  end
 if ~isfield(cfg,'suptemp3'),   cfg.suptemp3=0;  end
 if ~isfield(cfg,'suptemp4'),   cfg.suptemp4=0;  end
 if ~isfield(cfg,'inflated'),   cfg.inflated=1;  end
 if ~isfield(cfg,'area'),       cfg.area=1;  end
 if ~isfield(cfg,'applyxfm'),   cfg.applyxfm=0;  else, error('Applying transform not yet supported!'); end
 if ~isfield(cfg,'isocurv'),    cfg.isocurv=[]; end % this can take ~6 sec
end
if isfield(cfg,'suptemp1'), cfg.suptemp=cfg.suptemp1; end

HEMI = {'lh','rh'};
SURF = [];
SPHERE = cell(1,2);
PIAL   = cell(1,2);
WHITE  = cell(1,2);
MEAN   = cell(1,2);
INFL   = cell(1,2);
ANNOT  = cell(1,2);
SMOOTHWM = cell(1,2);
SMOOTHPIAL = cell(1,2);
SULC={}; PIALCURV={}; WHITECURV={};

SUPTEMP={};
for s=1:2
 hemi=HEMI{s};
 fname = fullfile(subjects_dir,sesid,'surf',[hemi,'.pial']);
 if cfg.ras
  [verts1, faces, cras, hdr] = FS_read_surf_ras(fname);
  cfg.cras = cras;
  cfg.fshdr = hdr;
 else
  [verts1, faces] = FS_read_surf(fname);
 end
 
 fname = fullfile(subjects_dir,sesid,'surf',[hemi,'.white']);
 if cfg.ras
  [verts2, faces] = FS_read_surf_ras(fname);
 else
  [verts2, faces] = FS_read_surf(fname);
 end
 pial=[]; pial.vertices=verts1; pial.faces = faces;
 PIAL{s} = pial;
 white=[];  white.vertices=verts2; white.faces=faces;
 WHITE{s} = white;
 
 fname = fullfile(subjects_dir,sesid,'surf',[hemi,'.sphere']);
 [verts3, faces] = FS_read_surf_ras(fname);
 sphere=[]; sphere.vertices=verts3; sphere.faces=faces;
 SPHERE{s} = sphere;
 
 if cfg.vnorm % normal vector??
  vnorm = getvnorm(white); % uses matlab graphics function
  WHITE{s}.vnorm = vnorm;
  vnorm = getvnorm(pial);
  PIAL{s}.vnorm = vnorm;
 end
 
 thns  = read_curv(fullfile(subjects_dir,sesid,'surf',[hemi,'.thickness']));
 thns  = reshape (thns, [size(verts1,1), 1]);
%  WHITE{s}.thns  = thns;
%  PIAL{s}.thns  = thns;
%  SPHERE{s}.thns = thns;
 THNS{s} = thns;
 
 meansurf=[];
 meansurf.vertices = (verts1+verts2)./2;
 meansurf.faces = faces;
 MEAN{s} = meansurf;
 
 fname = fullfile(subjects_dir,sesid,'surf',[hemi,'.inflated']);
 if cfg.ras
  [verts3, faces] = FS_read_surf_ras(fname);
 else
  [verts3, faces] = FS_read_surf(fname);
 end
 infl=[]; infl.vertices=verts3; infl.faces=faces;
 INFL{s} = infl;
 
 if cfg.smoothwm
  fname = fullfile(subjects_dir,sesid,'surf', ...
   [hemi,'.smoothwm.n',num2str(cfg.smoothwm)]);
  if strcmp(sesid,'fsaverage')
   meanEdgeLength = 0.7481;
  elseif strcmp(sesid,'fsaverage6')
   meanEdgeLength = 1.5134;
  elseif strcmp(sesid,'fsaverage5')
   meanEdgeLength = 2.9985;
   Ldist='1';
  else
   meanEdgeLength = 1;
   Ldist='10';
  end
  if ~exist(fname,'file') %|| 1
   fname1 = fullfile(subjects_dir,sesid,'surf',[hemi,'.white']);
   copyfile(fullfile(subjects_dir,sesid,'surf',[hemi,'.curv']),...
    fullfile(subjects_dir,sesid,'surf',[hemi,'.curv.old']));
   copyfile(fullfile(subjects_dir,sesid,'surf',[hemi,'.area']),...
    fullfile(subjects_dir,sesid,'surf',[hemi,'.area.old']));
   N=round(18/meanEdgeLength);
   system(['mris_smooth -n ',num2str(N),' ',fname1,' ',fname]);
   system(['mris_inflate -no-save-sulc -n ',num2str(cfg.smoothwm), ...
    ' -dist 0 ',fname,' ',fname]);
   N=round(18/meanEdgeLength);
   system(['mris_smooth -n ',num2str(N),' ',fname,' ',fname]);
   copyfile(fullfile(subjects_dir,sesid,'surf',[hemi,'.curv.old']),...
    fullfile(subjects_dir,sesid,'surf',[hemi,'.curv']));
   copyfile(fullfile(subjects_dir,sesid,'surf',[hemi,'.area.old']),...
    fullfile(subjects_dir,sesid,'surf',[hemi,'.area']));
  end
  if cfg.ras
   [vertex_coords, faces]  = FS_read_surf_ras(fname);
  else
   [vertex_coords, faces]  = FS_read_surf(fname);
  end
  smoothwm = []; smoothwm.vertices = vertex_coords; smoothwm.faces = faces;
  SMOOTHWM{s} = smoothwm;
 end
 
 if cfg.smoothpial
  fname = fullfile(subjects_dir,sesid,'surf', ...
   [hemi,'.smoothpial.n',num2str(cfg.smoothpial)]);
  if ~exist(fname,'file')
   fname1 = fullfile(subjects_dir,sesid,'surf',[hemi,'.pial']);
   system(['mris_inflate -no-save-sulc -n ', ...
    num2str(cfg.smoothpial),' -dist 0.1 ',fname1,' ',fname]);
  end
 end
 if cfg.ras
  [vertex_coords, faces]  = FS_read_surf_ras(fname);
 else
  [vertex_coords, faces]  = FS_read_surf(fname);
 end
 smoothpial = []; smoothpial.vertices = vertex_coords; smoothpial.faces = faces;
 SMOOTHPIAL{s} = smoothpial;
 
 fname = fullfile(subjects_dir,sesid,'label',[hemi,'.aparc.annot']);
 [verts, label, cot] = read_annotation( fname, 0 );
 ANNOT{s}.verts = verts;
 ANNOT{s}.label = label;
 ANNOT{s}.cot = cot;
 ANNOT{s}.cortex = ...
  (ANNOT{s}.label ~= cot.table(1,5)) & ... % 'unknown'
  (ANNOT{s}.label ~= cot.table(5,5));      % 'corpuscallosum'
 ANNOT{s}.cortex(~ANNOT{s}.label)=0;
 ANNOT{s}.cot.short_struct_names={
    'unknown'
    'STS'
    'ACC'
    'CMF'
    'CC'
    'CN'
    'Entr'
    'FFC'
    'IPL'
    'ITC'
    'ITHC'
    'LtOcc'
    'LtOFC'
    'LNG'
    'MOFC'
    'MTC'
    'PrHC'
    'PrC'
    'POC'
    'POrb'
    'PTri'
    'PrCCR'
    'PstC'
    'PstCC'
    'PreC'
    'PreCN'
    'RLCC'
    'RMFC'
    'SFC'
    'SPC'
    'STC'
    'SMG'
    'FP'
    'TP'
    'TT'
    'Ins'
  };
 lobes={'';'T';'C';'F';'';'O';'T';'T';'P';'T';'C';'O';'F';'O';'F';...
   'T';'T';'F';'F';'F';'F';'O';'P';'C';'F';'P';'C';'F';'F';'P';'T';...
   'P';'F';'F';'T';'I'};
 LOBES='FTPOCI';
 ANNOT{s}.lobes=ANNOT{s}.cortex*0;
 for j=1:6
  [~,idx]=ismember(lobes, LOBES(j));
  idx = find(idx);
  for i=1:numel(idx)
   ANNOT{s}.lobes(ANNOT{s}.label == ANNOT{s}.cot.table(idx(i),5)) = j;
  end
 end
 ANNOT{s}.lobenames = ...
   {'Frontal','Temporal','Parietal','Occipital','Cingulate','Insula'};
   
 fname = fullfile(subjects_dir,sesid,'label',[hemi,'.aparc.a2009s.annot']);
 [verts2, label2, cot2] = read_annotation( fname, 0 );
 ANNOT{s}.a2009s.verts = verts2;
 ANNOT{s}.a2009s.label = label2;
 ANNOT{s}.a2009s.cot = cot2;
 
 [~,names] = xlsread('~/Dropbox/sgfunc/a2009s_longname.xls','Sheet1');
 ANNOT{s}.a2009s.cot.struct_longnames = names(:,5);
 ANNOT{s}.a2009s.cot.struct_verylongnames = names(:,6);
 for sj=1:size(names,1)
  ANNOT{s}.a2009s.cot.struct_init{sj} = [names{sj,2},'-',upper(HEMI{s}(1))];
 end
 
 fname = fullfile(subjects_dir,sesid,'surf',[hemi,'.curv']);
 whitecurv = read_curv(fname);
 WHITECURV{s} = whitecurv;
 
 fname = fullfile(subjects_dir,sesid,'surf',[hemi,'.curv.pial']);
 if ~exist(fname,'file')
  PIALCURV{s} = whitecurv;
 else
  pialcurv = read_curv(fname);
  PIALCURV{s} = pialcurv;
 end
 
 % read sulcal depth
 fname = fullfile(subjects_dir,sesid,'surf',[hemi,'.sulc']);
 SULC{s} = read_curv(fname);
 
 if cfg.suptemp
  % Patch #1. automatic superior temporal
  % superior temporal   = 31th, cot.table(31,5)= 14474380
  % transverse temporal = 35th, cot.table(35,5)= 13145750
  ANNOT{s}.suptemp1 = find( (label == cot.table(31,5)) ...
   + (label == cot.table(35,5)));
  fname1 = fullfile(subjects_dir, sesid, 'surf',[HEMI{s},'.suptemp.patch']);
  label2patch(infl, ANNOT{s}.suptemp1, fname1);
  patch = read_patch(fname1);
  % in some cases, the # of vertices are different due to the flattening
  ANNOT{s}.suptemp1 = patch.ind+1;
  ANNOT{s}.suptemp1_bin = ismember(1:size(pial.vertices,1), ANNOT{s}.suptemp1);
  
  % get pial,white,infl surfs
  SUPTEMP.pial{s}  = get_subsurf(PIAL{s}, ANNOT{s}.suptemp1 );
  SUPTEMP.white{s} = get_subsurf(WHITE{s}, ANNOT{s}.suptemp1 );
  SUPTEMP.mean{s}  = get_subsurf(MEAN{s}, ANNOT{s}.suptemp1 );
  SUPTEMP.infl{s}  = get_subsurf(INFL{s}, ANNOT{s}.suptemp1 );
  if cfg.smoothwm
   SUPTEMP.smoothwm{s} = get_subsurf(SMOOTHWM{s}, ANNOT{s}.suptemp1 );
  end
 end
 
 if cfg.suptemp2
  % Patch #2. Larger automatic parcellation
  % [+ autoseg sup temp + trans temp + insula(36) + supramarginal (32)]
  %   G_temp_sup-Lateral(35)
  %   G_temp_sup-G_T_transv(34), S_temporal_transverse(76),
  %   G_temp_sup-Plan_tempo(37), Lat_Fis-post(42),
  %   S_circular_insula_inf(50), G_temp_sup-Plan_polar(36)
  % even more? (to encapsulate the basins...)
  % G_pariet_inf-Supramar(27)
  % G_insular_short(19)
  % G_Ins_Ig_and_S_cent(18)
  % S_cirular_insula_sup(51)
  % S_interm_prim-Jensen(57)
  % G_and_S_subcentral(5)
  % Pole_temporal(45)
  ANNOT{s}.suptemp2 = find( ...
   (label == cot.table(31,5)) + (label == cot.table(35,5)) ...
   + (label == cot.table(36,5)) + (label == cot.table(32,5)) ...
   + (label2 == cot2.table(35,5)) ...
   + (label2 == cot2.table(34,5)) + (label2 == cot2.table(76,5)) ...
   + (label2 == cot2.table(37,5)) + (label2 == cot2.table(42,5)) ...
   + (label2 == cot2.table(50,5))  ...
   + (label2 == cot2.table(27,5)) + (label2 == cot2.table(19,5)) ...
   + (label2 == cot2.table(18,5)) + (label2 == cot2.table(51,5)) ...
   + (label2 == cot2.table(57,5)) + (label2 == cot2.table( 5,5)) ...
   + (label2 == cot2.table(57,5)) );
  fname1 = fullfile(subjects_dir, sesid, 'surf',[HEMI{s},'.suptemp2.patch']);
  label2patch(infl, ANNOT{s}.suptemp2, fname1);
  patch = read_patch(fname1);
  % in some cases, the # of vertices are different due to the flattening
  ANNOT{s}.suptemp2 = patch.ind+1;
  ANNOT{s}.suptemp2_bin = ismember(1:size(pial.vertices,1), ANNOT{s}.suptemp2);
  %  end
  
  SUPTEMP2.pial{s}  = get_subsurf(PIAL{s}, ANNOT{s}.suptemp2 );
  SUPTEMP2.white{s} = get_subsurf(WHITE{s}, ANNOT{s}.suptemp2 );
  SUPTEMP2.mean{s}  = get_subsurf(MEAN{s}, ANNOT{s}.suptemp2 );
  SUPTEMP2.infl{s}  = get_subsurf(INFL{s}, ANNOT{s}.suptemp2 );
  if cfg.smoothwm
   SUPTEMP2.smoothwm{s} = get_subsurf(SMOOTHWM{s}, ANNOT{s}.suptemp2 );
  end
 end
 
 if cfg.suptemp3
  %     % Patch #3. Smaller supratemporal plane for qT1 analysis
  %     % superior temporal   = 31th, cot.table(31,5)= 14474380
  %     % transverse temporal = 35th, cot.table(35,5)= 13145750
  % G_pariet_inf-Supramar(27)
  % G_insular_short(19)
  % G_Ins_Ig_and_S_cent(18)
  % S_cirular_insula_sup(51)
  % S_interm_prim-Jensen(57)
  % G_and_S_subcentral(5)
  % Pole_temporal(45)
  % patch #3. supratemporal plane from a2009s... with some planum temporale
  label_c = ANNOT{s}.a2009s.cot.table(ismember(ANNOT{s}.a2009s.cot.struct_names, ...
   'G_temp_sup-Plan_polar'),5);
  label_d = ANNOT{s}.a2009s.cot.table(ismember(ANNOT{s}.a2009s.cot.struct_names, ...
   'S_temporal_sup'),5);
  label_e = ANNOT{s}.a2009s.cot.table(ismember(ANNOT{s}.a2009s.cot.struct_names, ...
   'G_temp_sup-Lateral'),5);
  label_f = ANNOT{s}.a2009s.cot.table(ismember(ANNOT{s}.a2009s.cot.struct_names, ...
   'S_circular_insula_inf'),5);
  label_g = ANNOT{s}.a2009s.cot.table(ismember(ANNOT{s}.a2009s.cot.struct_names, ...
   'G_temp_sup-G_T_transv'),5);
  label_h = ANNOT{s}.a2009s.cot.table(ismember(ANNOT{s}.a2009s.cot.struct_names, ...
   'S_temporal_transverse'),5);
  label_i = ANNOT{s}.a2009s.cot.table(ismember(ANNOT{s}.a2009s.cot.struct_names, ...
   'G_temp_sup-Plan_tempo'),5);
  label_j = ANNOT{s}.a2009s.cot.table(ismember(ANNOT{s}.a2009s.cot.struct_names, ...
   'Lat_Fis-post'),5);
  label_k = ANNOT{s}.a2009s.cot.table(ismember(ANNOT{s}.a2009s.cot.struct_names, ...
   'G_pariet_inf-Supramar'),5);
  label_l = ANNOT{s}.a2009s.cot.table(ismember(ANNOT{s}.a2009s.cot.struct_names, ...
   'G_Ins_Ig_and_S_cent_ins'),5);
  mask_ROI= ismember(ANNOT{s}.a2009s.label, [label_c, label_d, label_e, label_f, ...
   label_g, label_h, label_i, label_j, label_k, label_l]);
  ANNOT{s}.suptemp3_bin = mask_ROI;
  ANNOT{s}.suptemp3     = find(mask_ROI);
  
  fname1 = fullfile(subjects_dir, sesid, 'surf',[HEMI{s},'.suptemp3.patch']);
  label2patch(infl, ANNOT{s}.suptemp3, fname1);
  patch = read_patch(fname1);
  % in some cases, the # of vertices are different due to the flattening
  ANNOT{s}.suptemp3 = patch.ind+1;
  ANNOT{s}.suptemp3_bin = ismember(1:size(pial.vertices,1), ANNOT{s}.suptemp3);
  
  % get pial,white,infl surfs
  SUPTEMP3.pial{s}  = get_subsurf(PIAL{s}, ANNOT{s}.suptemp3 );
  SUPTEMP3.white{s} = get_subsurf(WHITE{s}, ANNOT{s}.suptemp3 );
  SUPTEMP3.mean{s}  = get_subsurf(MEAN{s}, ANNOT{s}.suptemp3 );
  SUPTEMP3.infl{s}  = get_subsurf(INFL{s}, ANNOT{s}.suptemp3 );
  if cfg.smoothwm
   SUPTEMP3.smoothwm{s} = get_subsurf(SMOOTHWM{s}, ANNOT{s}.suptemp3 );
  end
 end
 
 if cfg.suptemp4
  % Patch #4. Patch#2 + STS
  % even more? (to encapsulate the basins...)
  % G_pariet_inf-Supramar(27)
  % G_insular_short(19)
  % G_Ins_Ig_and_S_cent(18)
  % S_cirular_insula_sup(51)
  % S_interm_prim-Jensen(57)
  % G_and_S_subcentral(5)
  % Pole_temporal(45)
  % STS (75)
  ANNOT{s}.suptemp4 = find( ...
   (label == cot.table(31,5)) + (label == cot.table(35,5)) ...
   + (label == cot.table(36,5)) + (label == cot.table(32,5)) ...
   + (label2 == cot2.table(35,5)) ...
   + (label2 == cot2.table(34,5)) + (label2 == cot2.table(76,5)) ...
   + (label2 == cot2.table(37,5)) + (label2 == cot2.table(42,5)) ...
   + (label2 == cot2.table(50,5))  ...
   + (label2 == cot2.table(27,5)) + (label2 == cot2.table(19,5)) ...
   + (label2 == cot2.table(18,5)) + (label2 == cot2.table(51,5)) ...
   + (label2 == cot2.table(57,5)) + (label2 == cot2.table( 5,5)) ...
   + (label2 == cot2.table(57,5)) + (label2 == cot2.table(75,5)) );
  fname1 = fullfile(subjects_dir, sesid, 'surf',[HEMI{s},'.suptemp4.patch']);
  label2patch(infl, ANNOT{s}.suptemp4, fname1);
  patch = read_patch(fname1);
  % in some cases, the # of vertices are different due to the flattening
  ANNOT{s}.suptemp4 = patch.ind+1;
  ANNOT{s}.suptemp4_bin = ismember(1:size(pial.vertices,1), ANNOT{s}.suptemp4);
  %  end
  
  SUPTEMP4.pial{s}  = get_subsurf(PIAL{s}, ANNOT{s}.suptemp4 );
  SUPTEMP4.white{s} = get_subsurf(WHITE{s}, ANNOT{s}.suptemp4 );
  SUPTEMP4.mean{s}  = get_subsurf(MEAN{s}, ANNOT{s}.suptemp4 );
  SUPTEMP4.infl{s}  = get_subsurf(INFL{s}, ANNOT{s}.suptemp4 );
  if cfg.smoothwm
   SUPTEMP4.smoothwm{s} = get_subsurf(SMOOTHWM{s}, ANNOT{s}.suptemp4 );
  end
 end
 
 if cfg.hn
  % Patch #A. Humphries Neuroimage (HN)
  fname1 = fullfile(subjects_dir, sesid, 'surf',[HEMI{s},'.HN.patch']);
  patch  = read_patch(fname1);
  % in some cases, the # of vertices are different due to the flattening
  ANNOT{s}.hn = patch.ind+1;
 end
 
 if cfg.hnn
  % Patch #B. Humphries Neuroimage - NARROW (HNN)
  fname1 = fullfile(subjects_dir, sesid, 'surf',[HEMI{s},'.HNN.patch']);
  patch  = read_patch(fname1);
  % in some cases, the # of vertices are different due to the flattening
  ANNOT{s}.hnn = patch.ind+1;
 end
 
 % get flat surfs
 if cfg.flat
  fname1 = fullfile(subjects_dir, sesid, 'surf',[HEMI{s},'.suptemp.patch']);
  % find (or create) a flattened patch
  fname2= fullfile(subjects_dir, sesid, 'surf',[HEMI{s},'.suptemp.flat.patch']);
  if ~exist (fname2, 'file')
   system(['mris_flatten ',fname1,' ',fname2]);
  end
  flatpatch = read_patch(fname2);
  ANNOT{s}.suptemp1 = flatpatch.ind+1;
  ANNOT{s}.suptemp1_bin = ismember(1:size(pial.vertices,1), ANNOT{s}.suptemp1);
  
  % get subsurfs
  SUPTEMP.pial{s}  = get_subsurf(PIAL{s}, ANNOT{s}.suptemp1 );
  SUPTEMP.white{s} = get_subsurf(WHITE{s}, ANNOT{s}.suptemp1 );
  SUPTEMP.infl{s} = get_subsurf(INFL{s}, ANNOT{s}.suptemp1 );
  if cfg.smoothwm
   SUPTEMP.smoothwm{s} = get_subsurf(SMOOTHWM{s}, ANNOT{s}.suptemp1 );
  end
  
  % reorient with PCA
  [~,PCs] = pca([flatpatch.x; flatpatch.y]');
  SUPTEMP.flat{s}.vertices = [PCs(:,1), PCs(:,2), flatpatch.z'];
  SUPTEMP.flat{s}.faces = SUPTEMP.pial{s}.faces;
  
  % rotate flattened patches (medial to up)
  [~,ind1] = min(SUPTEMP.flat{s}.vertices(:,2));
  [~,ind2] = max(SUPTEMP.flat{s}.vertices(:,2));
  bottomtop = [ind1 ind2];
  if SUPTEMP.pial{s}.vertices(bottomtop(1),3) > SUPTEMP.pial{s}.vertices(bottomtop(2),3)
   SUPTEMP.flat{s}.vertices = - SUPTEMP.flat{s}.vertices;
  end
  
  % pial curvature for visualization
  SUPTEMP.flat{s}.curv = SURF.PIALCURV{s}(ANNOT{s}.suptemp1);
  SUPTEMP.flat{s}.vert_idx1_orig = SUPTEMP.pial{s}.vert_idx1_orig;
 end
 % get flat surf: suptemp2
 if cfg.flat2
  fname1 = fullfile(subjects_dir, sesid, 'surf',[HEMI{s},'.suptemp2.patch']);
  % find (or create) a flattened patch
  fname2= fullfile(subjects_dir, sesid, 'surf',[HEMI{s},'.suptemp2.flat.patch']);
  if ~exist (fname2, 'file')
   system(['mris_flatten ',fname1,' ',fname2]);
  end
  flatpatch = read_patch(fname2);
  ANNOT{s}.suptemp2 =  flatpatch.ind+1;
  ANNOT{s}.suptemp2_bin = ismember(1:size(pial.vertices,1), ANNOT{s}.suptemp2);
  % get subsurf
  SUPTEMP2.pial{s}  = get_subsurf(PIAL{s}, ANNOT{s}.suptemp2 );
  SUPTEMP2.white{s} = get_subsurf(WHITE{s}, ANNOT{s}.suptemp2 );
  SUPTEMP2.mean{s}  = get_subsurf(MEAN{s}, ANNOT{s}.suptemp2 );
  SUPTEMP2.infl{s}  = get_subsurf(INFL{s}, ANNOT{s}.suptemp2 );
  if cfg.smoothwm
   SUPTEMP2.smoothwm{s} = get_subsurf(SMOOTHWM{s}, ANNOT{s}.suptemp2 );
  end
  
  % reorient with PCA
  [~,PCs] = pca([flatpatch.x; flatpatch.y]');
  SUPTEMP2.flat{s}.vertices = [PCs(:,1), PCs(:,2), flatpatch.z'];
  SUPTEMP2.flat{s}.faces = SUPTEMP2.pial{s}.faces;
  
  % rotate flattened patches (medial to up)
  [~,ind1] = min(SUPTEMP2.flat{s}.vertices(:,2)); % vertex with y-min
  [~,ind2] = max(SUPTEMP2.flat{s}.vertices(:,2)); % vertex with y-max
  bottomtop = [ind1 ind2];
  % for Z-coordinate
  if SUPTEMP2.infl{s}.vertices(bottomtop(1),3) > SUPTEMP2.infl{s}.vertices(bottomtop(2),3)
   SUPTEMP2.flat{s}.vertices = -SUPTEMP2.flat{s}.vertices;
  end
  
  % pial curvature for visualization
  SUPTEMP2.flat{s}.curv = SURF.PIALCURV{s}(ANNOT{s}.suptemp2);
  SUPTEMP2.flat{s}.vert_idx1_orig = SUPTEMP2.pial{s}.vert_idx1_orig;
  
  % get subsurfs
  SUPTEMP2.pial{s}  = get_subsurf(PIAL{s}, ANNOT{s}.suptemp2 );
  SUPTEMP2.white{s} = get_subsurf(WHITE{s}, ANNOT{s}.suptemp2 );
  SUPTEMP2.infl{s}  = get_subsurf(INFL{s}, ANNOT{s}.suptemp2 );
  if cfg.smoothwm
   SUPTEMP2.smoothwm{s} = get_subsurf(SMOOTHWM{s}, ANNOT{s}.suptemp2 );
  end
 end
 
 if cfg.hn
  fname1 = fullfile(subjects_dir, sesid, 'surf',[HEMI{s},'.HN.patch']);
  % find (or create) a flattened patch
  fname2= fullfile(subjects_dir, sesid, 'surf',[HEMI{s},'.HN.flat.patch']);
  if ~exist (fname2, 'file')
   system(['mris_flatten ',fname1,' ',fname2]);
  end
  flatpatch = read_patch(fname2);
  ANNOT{s}.hn = flatpatch.ind+1;
  
  % get subsurfs
  HN.pial{s}  = get_subsurf(PIAL{s}, ANNOT{s}.hn );
  HN.white{s} = get_subsurf(WHITE{s}, ANNOT{s}.hn );
  HN.infl{s} = get_subsurf(INFL{s}, ANNOT{s}.hn );
  if cfg.smoothwm
   HN.smoothwm{s} = get_subsurf(SMOOTHWM{s}, ANNOT{s}.hn );
  end
  
  % reorient with PCA
  [~,PCs] = pca([flatpatch.x; flatpatch.y]');
  HN.flat{s}.vertices = [PCs(:,1), PCs(:,2), flatpatch.z'];
  HN.flat{s}.faces = HN.pial{s}.faces;
  
  % rotate flattened patches (medial to up)
  [~,ind1] = min(HN.flat{s}.vertices(:,2));
  [~,ind2] = max(HN.flat{s}.vertices(:,2));
  bottomtop = [ind1 ind2];
  if HN.pial{s}.vertices(bottomtop(1),3) > HN.pial{s}.vertices(bottomtop(2),3)
   HN.flat{s}.vertices = - HN.flat{s}.vertices;
  end
  
  % pial curvature for visualization
  HN.flat{s}.curv = SURF.PIALCURV{s}(ANNOT{s}.hn);
 end
 
 if cfg.hnn
  fname1 = fullfile(subjects_dir, sesid, 'surf',[HEMI{s},'.HNN.patch']);
  % find (or create) a flattened patch
  fname2 = fullfile(subjects_dir, sesid, 'surf',[HEMI{s},'.HNN.flat.patch']);
  if ~exist (fname2, 'file')
   system(['mris_flatten ',fname1,' ',fname2]);
  end
  flatpatch    = read_patch(fname2);
  ANNOT{s}.hnn = flatpatch.ind+1;
  
  % get subsurfs
  HNN.pial{s}     = get_subsurf(PIAL{s}, ANNOT{s}.hnn );
  HNN.white{s}    = get_subsurf(WHITE{s}, ANNOT{s}.hnn );
  HNN.infl{s}     = get_subsurf(INFL{s}, ANNOT{s}.hnn );
  if cfg.smoothwm
   HNN.smoothwm{s} = get_subsurf(SMOOTHWM{s}, ANNOT{s}.hnn );
  end
  
  % reorient with PCA
  [~,PCs] = pca([flatpatch.x; flatpatch.y]');
  HNN.flat{s}.vertices = [PCs(:,1), PCs(:,2), flatpatch.z'];
  HNN.flat{s}.faces = HNN.pial{s}.faces;
  %[vertex_coords, faces, cras, hdr]
  
  % rotate flattened patches (medial to up)
  [~,ind1] = min(HNN.flat{s}.vertices(:,2));
  [~,ind2] = max(HNN.flat{s}.vertices(:,2));
  bottomtop = [ind1 ind2];
  if HNN.pial{s}.vertices(bottomtop(1),3) > HNN.pial{s}.vertices(bottomtop(2),3)
   HNN.flat{s}.vertices = - HNN.flat{s}.vertices;
  end
  
  % pial curvature for visualization
  HNN.flat{s}.curv = SURF.PIALCURV{s}(ANNOT{s}.hnn);
 end
 if cfg.area
  AREA{s} = read_curv([subjects_dir,'/',sesid,'/surf/',HEMI{s},'.area']);
 end
end

if isfield(cfg,'smallmeshes')
 for s=1:2
  SURF.pial{s}=reducepatch(SURF.PIAL{s},0.1);
  SURF.white{s}=reducepatch(SURF.WHITE{s},0.1);
  SURF.infl{s}=reducepatch(SURF.INFL{s},0.1);
 end
end

% if cfg.applyxfm
%  % coregistration from native to mni305 space
%  fname_xfm = fullfile(subjects_dir,sesid,'mri','transforms','coreg_fsavg.xfm');
%  fname_moving = fullfile(subjects_dir,sesid,'mri','brainmask.nii');
%  if ~exist(fname_moving,'file')
%   myunix(['mri_convert ',fullfile(subjects_dir,sesid,'mri','brainmask.mgz'), ...
%    ' ',fname_moving]);
%  end
%  fname_fixed  = fullfile(subjects_dir,'fsaverage','mri','brain.nii');
%  if ~exist(fname_fixed,'file')
%   myunix(['mri_convert ',fullfile(subjects_dir,'fsaverage','mri','brainmask.mgz'), ...
%    ' ',fname_fixed]);
%  end
%  coreg = myspm_coreg_est(fname_moving, fname_fixed, fname_xfm);
% end

fieldnames={'PIAL','WHITE','INFL','SPHERE','MEAN','SMOOTHWM'};
fieldnames_cfg={'pial','white','inflated','sphere','mean','smoothwm'};
for j=1:numel(fieldnames)
 eval(['if cfg.',(fieldnames_cfg{j}),', ', ...
  'SURF.',fieldnames{j},'=',fieldnames{j},';', ...
  'if cfg.applyxfm, ', ...
  'verts=SURF.',fieldnames{j},'{1}.vertices;', ...
  'verts = [verts''; zeros(1,size(verts,1))]; verts = coreg.T * verts;', ...
  'SURF.',fieldnames{j},'{1}.vertices=verts(1:3,:)''; ', ...
  'verts=SURF.',fieldnames{j},'{2}.vertices;', ...
  'verts = [verts''; zeros(1,size(verts,1))]; verts = coreg.T * verts;', ...
  'SURF.',fieldnames{j},'{2}.vertices=verts(1:3,:)''; ', ...
  'end;end;']);
end

fieldnames={'SUPTEMP','SUPTEMP2', 'SUPTEMP3', 'SUPTEMP4', 'HN','HNN'};
fieldnames_cfg={'suptemp','suptemp2','suptemp3','suptemp4','hn','hnn'};
for j=1:numel(fieldnames)
 cmd=['if cfg.',(fieldnames_cfg{j}),', ', ...
  'SURF.',fieldnames{j},'=',fieldnames{j},';', ...
  'if cfg.applyxfm, '];
 surftypes={'pial','white','mean','infl'};
 for t=1:4
  cmd=[cmd 'verts=SURF.',fieldnames{j},'.',surftypes{t},'{1}.vertices;', ...
   'verts = [verts''; zeros(1,size(verts,1))]; verts = T * verts;', ...
   'SURF.',fieldnames{j},'.',surftypes{t},'{1}.vertices=verts(1:3,:)''; ', ...
   'verts=SURF.',fieldnames{j},'.',surftypes{t},'{2}.vertices;', ...
   'verts = [verts''; zeros(1,size(verts,1))]; verts = T * verts;', ...
   'SURF.',fieldnames{j},'.',surftypes{t},'{2}.vertices=verts(1:3,:)''; '];
 end
 cmd=[cmd,'; end;end;'];
 eval(cmd)
end

%% OUTPUT
SURF.subject = sesid;
SURF.subjects_dir = subjects_dir;
SURF.SULC = SULC;
SURF.WHITECURV = WHITECURV;
SURF.PIALCURV = PIALCURV;
SURF.ANNOT = ANNOT;
if cfg.area
 SURF.AREA=AREA;
end
SURF.THNS = THNS;
SURF.edge_length.pial = [mean(compute_edge_length(PIAL{1})), mean(compute_edge_length(PIAL{2}))];
SURF.edge_length.white = [mean(compute_edge_length(WHITE{1})), mean(compute_edge_length(WHITE{2}))];

%% Isocurvature (2020-03-24)
if ~isempty(cfg.isocurv)
  for s = 1:2
    [~,c] = tricontour(SURF.(cfg.isocurv){s}, ...
      SURF.WHITECURV{s}.*SURF.ANNOT{s}.cortex, 0, false);
    SURF.(cfg.isocurv){s}.isocurv = c.group;
  end
end

end
